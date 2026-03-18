#!/bin/bash

# ============================================================================
# n8n Quick Start & Management Script
# ============================================================================
# Description: Automated setup, deployment, and management for n8n on Docker
# Usage: ./n8n-manager.sh [command]
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
N8N_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE="${N8N_DIR}/docker-compose.yml"
BACKUP_DIR="${N8N_DIR}/backups"
LOG_FILE="${N8N_DIR}/n8n-manager.log"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        return 1
    fi
    success "Docker is installed ($(docker --version))"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        return 1
    fi
    success "Docker Compose is installed ($(docker-compose --version))"
}

check_docker_running() {
    if ! docker ps &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
        return 1
    fi
    success "Docker daemon is running"
}

check_n8n_compose() {
    if [ ! -f "$DOCKER_COMPOSE" ]; then
        error "docker-compose.yml not found at $N8N_DIR"
        return 1
    fi
    success "docker-compose.yml found"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

init() {
    log "Initializing n8n setup..."
    
    cd "$N8N_DIR"
    
    # Create necessary directories
    mkdir -p "$BACKUP_DIR"
    mkdir -p n8n-data
    
    # Check if .env exists
    if [ ! -f "$N8N_DIR/.env" ]; then
        if [ -f "$N8N_DIR/.env.template" ]; then
            log "Creating .env from template..."
            cp "$N8N_DIR/.env.template" "$N8N_DIR/.env"
            warning "Please edit .env file with your configuration!"
        else
            error ".env or .env.template not found"
            return 1
        fi
    fi
    
    # Validate docker-compose.yml
    if ! docker-compose config > /dev/null 2>&1; then
        error "Invalid docker-compose.yml syntax"
        return 1
    fi
    
    success "Initialization complete"
    return 0
}

# ============================================================================
# INSTALLATION & SETUP
# ============================================================================

install() {
    log "Installing n8n..."
    
    check_docker || return 1
    check_docker_running || return 1
    check_docker_compose || return 1
    init || return 1
    
    # Pull images
    log "Pulling Docker images..."
    docker-compose pull
    
    success "Installation complete"
    log "Next step: Run './n8n-manager.sh start' to start n8n"
}

# ============================================================================
# STARTUP & SHUTDOWN
# ============================================================================

start() {
    log "Starting n8n..."
    
    check_n8n_compose || return 1
    check_docker_running || return 1
    
    cd "$N8N_DIR"
    
    # Start containers
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 10
    
    # Check health
    if docker-compose ps | grep -q "healthy"; then
        success "n8n started successfully"
        log "Access n8n at: http://YOUR_EC2_PUBLIC_IP:5678"
    else
        warning "n8n may still be starting... checking logs"
        docker-compose logs -f n8n &
    fi
}

stop() {
    log "Stopping n8n..."
    
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    docker-compose down
    
    success "n8n stopped"
}

restart() {
    log "Restarting n8n..."
    
    stop || return 1
    sleep 5
    start || return 1
    
    success "n8n restarted"
}

# ============================================================================
# LOGS & MONITORING
# ============================================================================

logs() {
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    if [ -n "$1" ]; then
        # Follow specific container logs
        docker-compose logs -f "$1"
    else
        # Follow all logs
        docker-compose logs -f
    fi
}

status() {
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    echo ""
    log "=== Service Status ==="
    docker-compose ps
    
    echo ""
    log "=== Resource Usage ==="
    docker stats --no-stream 2>/dev/null || docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}"
    
    echo ""
    log "=== Disk Usage ==="
    du -sh n8n-data/ 2>/dev/null || echo "n8n-data directory not found"
}

# ============================================================================
# BACKUPS
# ============================================================================

backup() {
    log "Creating backup..."
    
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="$BACKUP_DIR/n8n_backup_$TIMESTAMP.tar.gz"
    
    # Stop containers gracefully
    log "Stopping containers..."
    docker-compose down
    
    sleep 5
    
    # Create backup
    log "Creating archive..."
    tar -czf "$BACKUP_FILE" n8n-data/ .env 2>/dev/null || true
    
    # Restart containers
    log "Restarting services..."
    docker-compose up -d
    
    if [ -f "$BACKUP_FILE" ]; then
        local SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        success "Backup created: $BACKUP_FILE ($SIZE)"
        
        # Cleanup old backups (keep last 7 days)
        find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime +7 -delete
        log "Cleaned up old backups"
    else
        error "Backup failed"
        return 1
    fi
}

restore() {
    if [ -z "$1" ]; then
        error "Usage: $0 restore <backup_file>"
        echo "Available backups:"
        ls -lh "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        error "Backup file not found: $1"
        return 1
    fi
    
    log "Restoring from backup: $1"
    
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    # Stop containers
    log "Stopping containers..."
    docker-compose down
    
    sleep 5
    
    # Backup current data
    if [ -d "n8n-data" ]; then
        log "Backing up current data..."
        mv n8n-data "n8n-data.bak-$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Restore
    log "Extracting backup..."
    tar -xzf "$1"
    
    # Restart
    log "Restarting containers..."
    docker-compose up -d
    
    success "Restore complete"
}

list_backups() {
    log "Available backups:"
    echo ""
    if [ -d "$BACKUP_DIR" ]; then
        ls -lh "$BACKUP_DIR"/n8n_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    else
        echo "No backups directory found"
    fi
}

# ============================================================================
# UPDATES
# ============================================================================

update() {
    log "Updating n8n to latest version..."
    
    check_docker_running || return 1
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    # Backup before update
    log "Creating backup before update..."
    backup || warning "Backup failed, continuing anyway..."
    
    # Pull latest image
    log "Pulling latest image..."
    docker-compose pull
    
    # Restart with new image
    log "Restarting with new image..."
    docker-compose down
    sleep 5
    docker-compose up -d
    
    log "Waiting for update to complete..."
    sleep 15
    
    success "Update complete"
    logs n8n
}

# ============================================================================
# MAINTENANCE
# ============================================================================

prune_executions() {
    log "Pruning old execution data..."
    
    check_n8n_compose || return 1
    
    cd "$N8N_DIR"
    
    if [ ! -f "n8n-data/database.sqlite" ]; then
        warning "SQLite database not found - ensure n8n has run before"
        return 1
    fi
    
    # Delete executions older than 30 days
    docker exec n8n sqlite3 /home/node/.n8n/database.sqlite \
        "DELETE FROM execution WHERE startedAt < datetime('now', '-30 days');" 2>/dev/null || {
        warning "Could not prune executions (may be using PostgreSQL)"
    }
    
    success "Pruned old execution data"
}

clean_docker() {
    log "Cleaning up unused Docker resources..."
    
    docker system prune -a --force
    
    success "Docker cleanup complete"
}

# ============================================================================
# DEBUGGING & DIAGNOSTICS
# ============================================================================

diagnose() {
    log "=== n8n Diagnostics ==="
    echo ""
    
    log "System Information:"
    echo "OS: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "CPU cores: $(nproc)"
    echo "Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disk space: $(df -h / | awk 'NR==2 {print $2, "used:", $3}')"
    echo ""
    
    log "Docker Information:"
    docker --version
    docker-compose --version
    echo ""
    
    log "n8n Status:"
    if [ -f "$DOCKER_COMPOSE" ]; then
        cd "$N8N_DIR"
        docker-compose ps
    else
        error "docker-compose.yml not found"
    fi
    echo ""
    
    log "n8n Health:"
    if docker exec n8n wget --quiet --spider http://localhost:5678/healthz 2>/dev/null; then
        success "n8n is responding"
    else
        error "n8n is not responding"
    fi
    echo ""
    
    log "Disk Usage:"
    du -sh "$N8N_DIR"/n8n-data/ 2>/dev/null || echo "n8n-data not found"
    echo ""
    
    log "Recent Logs:"
    docker-compose logs --tail=20 2>/dev/null || echo "Could not retrieve logs"
}

# ============================================================================
# HELP & USAGE
# ============================================================================

show_help() {
    cat << EOF

${BLUE}╔════════════════════════════════════════════════════════════╗${NC}
${BLUE}║           n8n Docker Manager - Quick Start Guide           ║${NC}
${BLUE}╚════════════════════════════════════════════════════════════╝${NC}

${YELLOW}USAGE:${NC}
  ./n8n-manager.sh [command] [options]

${YELLOW}SETUP COMMANDS:${NC}
  install              Install n8n (pull Docker images, verify setup)
  init                 Initialize .env and directories

${YELLOW}RUNTIME COMMANDS:${NC}
  start                Start n8n
  stop                 Stop n8n
  restart              Restart n8n
  status               Check n8n status and resource usage
  logs [service]       View logs (optional: specify service)

${YELLOW}BACKUP & RESTORE:${NC}
  backup               Create backup of n8n data
  restore <file>       Restore from backup
  list-backups         List all available backups

${YELLOW}MAINTENANCE:${NC}
  update               Update n8n to latest version
  prune-executions     Delete old execution data
  clean                Clean up unused Docker resources

${YELLOW}DIAGNOSTICS:${NC}
  diagnose             Run system diagnostics
  help                 Show this help message

${YELLOW}EXAMPLES:${NC}
  ./n8n-manager.sh install              # Initial setup
  ./n8n-manager.sh start                # Start n8n
  ./n8n-manager.sh logs                 # View all logs
  ./n8n-manager.sh logs n8n             # View n8n logs only
  ./n8n-manager.sh backup               # Create backup
  ./n8n-manager.sh restore backups/n8n_backup_20240315_120000.tar.gz
  ./n8n-manager.sh update               # Update to latest version
  ./n8n-manager.sh status               # Check status

${YELLOW}CONFIGURATION:${NC}
  Edit .env file with your settings before first run
  Default port: 5678
  Data directory: n8n-data/
  Backups directory: backups/

${YELLOW}TROUBLESHOOTING:${NC}
  ./n8n-manager.sh diagnose             # Run diagnostics
  ./n8n-manager.sh logs n8n             # Check n8n logs
  Check .env file for correct settings
  Verify EC2 security group allows port 5678

${YELLOW}WEB ACCESS:${NC}
  http://YOUR_EC2_PUBLIC_IP:5678
  Default credentials are in .env file

${YELLOW}SUPPORT:${NC}
  n8n Docs: https://docs.n8n.io/
  Community: https://community.n8n.io/
  Issues: https://github.com/n8n-io/n8n/issues

EOF
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

main() {
    # Create log file if doesn't exist
    touch "$LOG_FILE"
    
    # Check if command provided
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local COMMAND="$1"
    shift
    
    case "$COMMAND" in
        install)
            install
            ;;
        init)
            init
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "$@"
            ;;
        backup)
            backup
            ;;
        restore)
            restore "$@"
            ;;
        list-backups)
            list_backups
            ;;
        update)
            update
            ;;
        prune-executions)
            prune_executions
            ;;
        clean)
            clean_docker
            ;;
        diagnose)
            diagnose
            ;;
        help)
            show_help
            ;;
        *)
            error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"