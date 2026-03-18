# n8n Docker Setup Guide for AWS EC2 (Ubuntu 22.04 LTS)

## 📋 Table of Contents
1. [System Overview](#system-overview)
2. [Prerequisites & Requirements](#prerequisites--requirements)
3. [Step 1: Initial System Setup](#step-1-initial-system-setup)
4. [Step 2: Docker Installation](#step-2-docker-installation)
5. [Step 3: Docker Compose Configuration](#step-3-docker-compose-configuration)
6. [Step 4: Running n8n](#step-4-running-n8n)
7. [Step 5: Accessing n8n](#step-5-accessing-n8n)
8. [Step 6: Backup & Data Persistence](#step-6-backup--data-persistence)
9. [Step 7: Maintenance & Updates](#step-7-maintenance--updates)
10. [Troubleshooting](#troubleshooting)

---

## System Overview

### Your EC2 Configuration
```
🖥️ EC2 CONFIGURATION
├── AMI: Ubuntu Server 22.04 LTS (64-bit)
├── Instance Type: t3.micro
├── Storage: 20 GB (gp3)
├── OS Details:
│   ├── PRETTY_NAME: Ubuntu 22.04.5 LTS
│   ├── VERSION: 22.04.5 LTS (Jammy Jellyfish)
│   ├── VERSION_CODENAME: jammy
│   └── ID: ubuntu
└── Note: Free tier eligible + sufficient for n8n
```

### System Specifications
- **OS**: Ubuntu 22.04.5 LTS (Jammy Jellyfish)
- **RAM**: 1 GB (t3.micro, suitable for development/small-scale automation)
- **Storage**: 20 GB EBS volume (gp3)
- **vCPUs**: 1 vCPU

### Why This Configuration Works
- Docker containerization isolates n8n dependencies
- 20GB storage accommodates n8n data + PostgreSQL database
- t3.micro provides sufficient performance for small automation workflows
- Ubuntu 22.04 LTS has long-term support and good Docker compatibility

---

## Prerequisites & Requirements

### Before You Start
Ensure you have:
- SSH access to your EC2 instance
- A public IP address or configured security group for web access
- Port 5678 open in security group (n8n default port)
- Basic Linux command-line knowledge

### System Requirements
- **Minimum RAM**: 1 GB (for t3.micro)
- **Minimum Storage**: 20 GB (recommended for SQLite + logs)
- **Minimum vCPUs**: 1 vCPU
- **Docker**: Version 20.10+ (will be installed)
- **Docker Compose**: Version 2.0+ (will be installed)

---

## Step 1: Initial System Setup

### 1.1 Connect to Your EC2 Instance

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### 1.2 Update System Packages

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y

# Install essential utilities
sudo apt install -y curl wget git nano htop
```

### 1.3 Verify System Information

```bash
# Check Ubuntu version
cat /etc/os-release

# Check available disk space
df -h

# Check RAM
free -h

# Check CPU
nproc
```

Expected Output:
```
              total        used        free
Mem:          973Mi        300Mi       600Mi
/dev/xvda1     20G         2G         18G
```

---

## Step 2: Docker Installation

### 2.1 Install Docker

#### Method A: Using Official Docker Repository (Recommended)

```bash
# Remove any previosuly installed docker
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Verify Docker installation
docker --version
docker compose version

# Expected output: Docker version 20.10.X or higher
```

### 2.2 Verify Docker Installation

```bash

# Check Docker info
docker info

# Check Docker daemon status
sudo systemctl status docker

# Enable Docker to start on boot
sudo systemctl enable docker
```

---

## Step 3: Docker Compose Configuration

### 3.1 Create Project Directory

```bash
# Create n8n directory
mkdir -p ~/n8n
cd ~/n8n

# Create data persistence directory
mkdir -p n8n-data

# Display directory structure
tree . 2>/dev/null || find . -type d
```

### 3.2 Create Docker Compose File (SQLite - Simple Setup)

**For small deployments or development**, use this lightweight configuration:

```bash
nano docker-compose.yml
```

Paste the following content:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    
    # Port configuration
    ports:
      - "5678:5678"
    
    # Environment variables
    environment:
      # Basic authentication
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your_secure_password_here
      
      # Database configuration (SQLite is default)
      - DB_TYPE=sqlite
      
      # Timezone setting
      - GENERIC_TIMEZONE=UTC
      
      # Optional: Enable webhook for external triggers
      - WEBHOOK_URL=http://your-ec2-public-ip:5678
      
      # Optional: Disable data and node options telemetry
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - N8N_METRICS=false
    
    # Volume mounts for data persistence
    volumes:
      - ./n8n-data:/home/node/.n8n
      
    # Resource limits (important for t3.micro)
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    
    # Logging configuration
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    # Health check
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

networks:
  default:
    name: n8n-network
```

### 3.3 Create Docker Compose File (PostgreSQL - Production Setup)

**For production deployments**, use PostgreSQL for better performance:

```bash
nano docker-compose-postgres.yml
```

Paste the following content:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=your_secure_postgres_password_here
      - POSTGRES_INITDB_ARGS=-c shared_preload_libraries=pg_stat_statements
    
    volumes:
      - postgres_data:/var/lib/postgresql/data
    
    ports:
      - "5432:5432"
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
    
    # Health check
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    
    ports:
      - "5678:5678"
    
    environment:
      # Database configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=your_secure_postgres_password_here
      
      # Authentication
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your_secure_password_here
      
      # General settings
      - GENERIC_TIMEZONE=UTC
      - WEBHOOK_URL=http://your-ec2-public-ip:5678
      - N8N_METRICS=false
    
    volumes:
      - n8n_data:/home/node/.n8n
    
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

volumes:
  postgres_data:
  n8n_data:

networks:
  default:
    name: n8n-network
```

### 3.4 Create Environment Configuration File (.env)

```bash
nano .env
```

Paste:

```env
# n8n Environment Configuration
# Generated for AWS EC2 Ubuntu 22.04 LTS

# ======================
# DEPLOYMENT ENVIRONMENT
# ======================
NODE_ENV=production

# ======================
# AUTHENTICATION
# ======================
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=YOUR_SECURE_PASSWORD_HERE

# ======================
# DATABASE (SQLite)
# ======================
DB_TYPE=sqlite

# ======================
# DATABASE (PostgreSQL - uncomment for production)
# ======================
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=postgres
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=n8n
# DB_POSTGRESDB_USER=n8n
# DB_POSTGRESDB_PASSWORD=YOUR_SECURE_POSTGRES_PASSWORD_HERE

# ======================
# TIMEZONE & LOCALE
# ======================
GENERIC_TIMEZONE=UTC

# ======================
# WEBHOOK CONFIGURATION
# ======================
# Replace with your actual EC2 public IP
WEBHOOK_URL=http://YOUR_EC2_PUBLIC_IP:5678

# ======================
# TELEMETRY & METRICS
# ======================
N8N_METRICS=false

# ======================
# EXECUTION
# ======================
EXECUTIONS_DATA_PRUNE_TIMEOUT=3600

# ======================
# LOGGING
# ======================
N8N_LOG_LEVEL=info
```

---

## Step 4: Running n8n

### 4.1 Validate Configuration

```bash
# Check if docker-compose.yml is valid
docker-compose config

# Expected: No errors, file structure displayed
```

### 4.2 Start n8n (SQLite - Simple Setup)

```bash
# Navigate to n8n directory
cd ~/n8n

# Pull the latest n8n image
docker-compose pull

# Start n8n in the background
docker-compose up -d

# View logs
docker-compose logs -f

# Press Ctrl+C to exit logs view
```

### 4.3 Start n8n (PostgreSQL - Production Setup)

```bash
# Navigate to n8n directory
cd ~/n8n

# Pull images
docker-compose -f docker-compose-postgres.yml pull

# Start all services
docker-compose -f docker-compose-postgres.yml up -d

# View logs
docker-compose -f docker-compose-postgres.yml logs -f

# Check service status
docker-compose -f docker-compose-postgres.yml ps
```

### 4.4 Verify Containers Running

```bash
# List running containers
docker ps

# Expected output should show 'n8n' container (and 'n8n-postgres' if using PostgreSQL)

# Check container logs
docker logs n8n

# Check container resource usage
docker stats
```

### 4.5 Wait for n8n to Start

```bash
# Monitor logs until ready
docker logs -f n8n | grep -i "listen"

# Look for message: "Server started successfully"

# Check container health
docker inspect --format='{{.State.Health.Status}}' n8n
# Should show "healthy" after ~40 seconds
```

---

## Step 5: Accessing n8n

### 5.1 Verify Network Connectivity

```bash
# Check if port 5678 is listening
sudo netstat -tulpn | grep 5678

# Alternative using ss command
sudo ss -tulpn | grep 5678

# Expected: tcp 0 0 0.0.0.0:5678 0.0.0.0:* LISTEN
```

### 5.2 AWS Security Group Configuration

1. Go to AWS EC2 Dashboard
2. Click on your instance → Security Groups
3. Edit Inbound Rules
4. Add Rule:
   - **Type**: Custom TCP
   - **Port Range**: 5678
   - **Source**: Your IP (or 0.0.0.0/0 for public access - less secure)
5. Save rules

### 5.3 Access n8n Web Interface

Open your browser and navigate to:

```
http://YOUR_EC2_PUBLIC_IP:5678
```

Example:
```
http://54.123.45.67:5678
```

### 5.4 Login Credentials

- **Username**: `admin` (or configured in docker-compose.yml)
- **Password**: Your secure password (configured in docker-compose.yml)

### 5.5 First Login Verification

1. Enter username and password
2. Set up your n8n user account
3. You should see the n8n dashboard with workflow editor

---

## Step 6: Backup & Data Persistence

### 6.1 Understanding Data Storage

**SQLite Setup:**
```
Workflow Data Location: ~/n8n/n8n-data/database.sqlite
Encryption Keys: ~/n8n/n8n-data/.n8n/
Credentials: ~/n8n/n8n-data/.n8n/credentials/
```

**PostgreSQL Setup:**
```
Database Container: n8n-postgres
Data Volume: postgres_data
n8n Data: n8n_data
```

### 6.2 Create Backup Script

```bash
nano ~/n8n/backup.sh
```

Paste:

```bash
#!/bin/bash

# n8n Backup Script
# Usage: ./backup.sh

BACKUP_DIR=~/n8n/backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$TIMESTAMP.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop containers gracefully
echo "Stopping n8n containers..."
cd ~/n8n
docker-compose down

# Wait a moment for graceful shutdown
sleep 5

# Create backup archive
echo "Creating backup archive..."
tar -czf "$BACKUP_FILE" n8n-data/

# Restart containers
echo "Restarting n8n..."
docker-compose up -d

# Verify backup
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Backup successful: $BACKUP_FILE ($SIZE)"
else
    echo "✗ Backup failed!"
    exit 1
fi

# Cleanup old backups (keep last 7 days)
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime +7 -delete

echo "Backup complete!"
```

Make it executable:

```bash
chmod +x ~/n8n/backup.sh
```

### 6.3 Restore Backup

```bash
# Stop containers
cd ~/n8n
docker-compose down

# Extract backup
tar -xzf backups/n8n_backup_20240315_120000.tar.gz

# Restart containers
docker-compose up -d

# Verify
docker-compose logs -f
```

### 6.4 Automated Daily Backups (Cron Job)

```bash
# Edit crontab
crontab -e

# Add this line for daily 2 AM backups:
0 2 * * * /home/ubuntu/n8n/backup.sh >> /home/ubuntu/n8n/backup.log 2>&1
```

---

## Step 7: Maintenance & Updates

### 7.1 Check Available Updates

```bash
# Pull latest n8n image
docker pull n8nio/n8n:latest

# Check current running version
docker inspect n8n | grep -i "image"
```

### 7.2 Update n8n to Latest Version

```bash
cd ~/n8n

# Backup before updating
./backup.sh

# Pull latest image
docker-compose pull

# Stop and restart with new image
docker-compose down
docker-compose up -d

# Monitor startup
docker-compose logs -f

# Verify health
docker ps | grep n8n
```

### 7.3 View n8n Version

```bash
# Check version in logs
docker exec n8n node -e "console.log(require('/opt/nodemodules/n8n/package.json').version)" 2>/dev/null || echo "Access n8n UI to check version"

# Check in web interface: Settings → About
```

### 7.4 Monitor Disk Usage

```bash
# Check n8n data size
du -sh ~/n8n/n8n-data/

# Check total disk usage
df -h /

# Monitor PostgreSQL size (if using)
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"
```

### 7.5 View Container Logs

```bash
# Follow logs in real-time
docker-compose logs -f

# Follow specific container
docker-compose logs -f n8n

# View last 100 lines
docker-compose logs --tail=100

# Export logs to file
docker-compose logs > n8n_logs_$(date +%Y%m%d_%H%M%S).txt
```

### 7.6 Restart n8n

```bash
# Soft restart (graceful)
docker-compose restart

# Hard restart (remove and recreate)
docker-compose down
docker-compose up -d
```

---

## Troubleshooting

### ❌ n8n Container Won't Start

**Symptom**: Container exits immediately

```bash
# Check logs
docker logs n8n

# Common causes:
# 1. Port 5678 already in use
# 2. Insufficient disk space
# 3. Permission issues with n8n-data directory

# Solution:
docker-compose down
docker-compose up -d
docker logs n8n  # Check detailed error
```

### ❌ Cannot Access Web Interface

**Symptom**: Connection refused or timeout

```bash
# 1. Verify container is running
docker ps | grep n8n

# 2. Check port binding
sudo netstat -tulpn | grep 5678

# 3. Verify security group allows port 5678
# 4. Check firewall (if enabled)
sudo ufw status

# 5. Verify n8n is listening
curl http://localhost:5678

# If that works but remote access fails:
# - Check EC2 security group inbound rules
# - Verify public IP in WEBHOOK_URL
```

### ❌ Workflows Not Executing

**Symptom**: Workflows fail with execution errors

```bash
# Check n8n logs
docker logs -f n8n

# Verify database connectivity
docker-compose exec n8n npm run start

# Check resource usage
docker stats n8n

# If out of memory:
# - Increase memory limit in docker-compose.yml
# - Reduce workflow complexity
# - Clear execution history
```

### ❌ High Disk Usage

**Symptom**: /dev/xvda1 disk full

```bash
# Check space
df -h

# Find large files
du -sh ~/n8n/n8n-data/* | sort -h

# Prune old executions
docker exec n8n sqlite3 /home/node/.n8n/database.sqlite \
  "DELETE FROM execution WHERE startedAt < datetime('now', '-30 days');"

# Or use UI: Settings → Execution Data → Prune
```

### ❌ Database Connection Error

**Symptom**: "Error connecting to database" in logs

**For PostgreSQL:**
```bash
# Verify postgres is running
docker ps | grep postgres

# Check postgres logs
docker logs n8n-postgres

# Verify credentials match in .env file
# Restart both services
docker-compose down
docker-compose up -d
```

### ❌ Memory Issues on t3.micro

**Symptom**: Out of Memory (OOM) errors

```bash
# Check memory usage
free -h
docker stats

# Solutions:
# 1. Reduce container memory limit (already set to 512MB)
# 2. Disable unnecessary workflows
# 3. Delete old execution data
# 4. Consider upgrading instance type (t3.small)
```

### 🔍 Debug Mode

Enable verbose logging:

```bash
# Edit docker-compose.yml and add:
# - N8N_LOG_LEVEL=debug

# Or restart with debug
docker-compose down
nano docker-compose.yml  # Add N8N_LOG_LEVEL=debug
docker-compose up -d
docker logs -f n8n
```

---

## Additional Resources

### n8n Documentation
- Official Docs: https://docs.n8n.io/
- Docker Setup: https://docs.n8n.io/hosting/installation/docker/
- Deployment Guides: https://docs.n8n.io/hosting/

### Docker Documentation
- Docker Docs: https://docs.docker.com/
- Docker Compose: https://docs.docker.com/compose/
- Best Practices: https://docs.docker.com/develop/

### AWS EC2 Resources
- EC2 User Guide: https://docs.aws.amazon.com/ec2/
- Security Groups: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html
- Free Tier: https://aws.amazon.com/free/

---

## Quick Reference Commands

```bash
# Start n8n
cd ~/n8n && docker-compose up -d

# Stop n8n
cd ~/n8n && docker-compose down

# View logs
docker-compose logs -f

# Restart n8n
docker-compose restart

# Backup data
~/n8n/backup.sh

# Update n8n
docker-compose pull && docker-compose up -d

# Check status
docker-compose ps

# Monitor resources
docker stats

# Clean up unused Docker resources
docker system prune -a
```

---

## Security Recommendations

1. ✅ Change default n8n password immediately
2. ✅ Keep n8n and Docker updated regularly
3. ✅ Use strong, unique credentials
4. ✅ Enable 2FA in n8n (if available in your version)
5. ✅ Restrict security group access to trusted IPs
6. ✅ Backup data regularly
7. ✅ Monitor logs for suspicious activity
8. ✅ Use HTTPS in production (with reverse proxy)
9. ✅ Consider VPN access for remote management
10. ✅ Regularly prune old execution data

---

**Last Updated**: March 2026
**Ubuntu Version**: 22.04.5 LTS
**n8n Stable**: Latest stable release
**Docker Compose Version**: 2.x

---

## Support & Community

- n8n Community Forum: https://community.n8n.io/
- n8n Discord: https://discord.gg/nwekxnxjsi
- GitHub Issues: https://github.com/n8n-io/n8n/issues
- Stack Overflow: Tag `n8n`
