# n8n Docker Quick Reference Cheat Sheet

## 📱 Quick Start (5 Minutes)

### 1️⃣ Initial Setup
```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Create n8n directory
mkdir -p ~/n8n && cd ~/n8n

# Copy docker-compose.yml and .env files to ~/n8n/
# Edit docker-compose.yml → Replace YOUR_EC2_PUBLIC_IP
# Edit .env → Set strong password
```

### 2️⃣ Install Docker (if not already installed)
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### 3️⃣ Start n8n

Go to the Official n8n Hosting Guide for the Local Setup with PostgreSQL (recommended for production):
https://github.com/n8n-io/n8n-hosting/blob/main/docker-compose/withPostgres/README.md

```bash
cd ~/n8n
docker-compose up -d
docker-compose logs -f  # Watch startup
```

### 4️⃣ Access Web Interface
```
http://YOUR_EC2_PUBLIC_IP:5678
Username: admin
Password: (from .env file)
```

---

## 🚀 Essential Commands

### Start/Stop/Restart
```bash
# Start n8n
docker-compose up -d

# Stop n8n
docker-compose down

# Restart n8n
docker-compose restart

# Restart specific container
docker-compose restart n8n
```

### View Logs
```bash
# View all logs
docker-compose logs

# Follow logs (real-time)
docker-compose logs -f

# Follow n8n logs only
docker-compose logs -f n8n

# Last 100 lines
docker-compose logs --tail=100

# Save logs to file
docker-compose logs > logs_$(date +%Y%m%d_%H%M%S).txt
```

### Check Status
```bash
# Running containers
docker ps

# Container details
docker-compose ps

# Resource usage
docker stats

# Health check
docker inspect --format='{{.State.Health.Status}}' n8n
```

---

## 💾 Backup & Restore

### Create Backup
```bash
# Manual backup
docker-compose down
tar -czf n8n_backup_$(date +%Y%m%d_%H%M%S).tar.gz n8n-data/ .env
docker-compose up -d
```

### Restore Backup
```bash
# Stop services
docker-compose down

# Extract backup
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# Start services
docker-compose up -d
```

---

## 🔄 Updates

### Update to Latest Version
```bash
# Backup first
docker-compose down && tar -czf backup.tar.gz n8n-data/

# Update
docker-compose pull
docker-compose up -d

# Monitor update
docker-compose logs -f
```

---

## 🔧 Configuration Changes

### Edit Environment Variables
```bash
# Edit .env file
nano .env

# Restart to apply changes
docker-compose restart
```

### Change Authentication Password
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Change N8N_BASIC_AUTH_PASSWORD
# Restart n8n
docker-compose restart n8n
```

### Change Port (if 5678 is taken)
```bash
# Edit docker-compose.yml
# Change ports: - "5678:5678" to - "8080:5678"

# Restart
docker-compose down
docker-compose up -d

# Access at http://YOUR_IP:8080
```

---

## 🧹 Maintenance

### Remove Old Execution Data
```bash
# Via Docker exec (SQLite)
docker exec n8n sqlite3 /home/node/.n8n/database.sqlite \
  "DELETE FROM execution WHERE startedAt < datetime('now', '-30 days');"

# Or access UI: Settings → Execution Data → Prune
```

### Clean Docker System
```bash
# Remove unused containers, images, networks
docker system prune -a --force

# Remove only unused containers
docker container prune -f

# Remove only unused images
docker image prune -a -f
```

### Check Disk Usage
```bash
# n8n data size
du -sh n8n-data/

# Total disk
df -h

# Detailed breakdown
du -sh n8n-data/*
```

---

## 🐛 Troubleshooting

### Container won't start
```bash
# Check logs
docker logs n8n

# Verify configuration
docker-compose config

# Rebuild containers
docker-compose down
docker-compose up -d

# Check for port conflicts
sudo netstat -tulpn | grep 5678
```

### Can't access web interface
```bash
# Verify container running
docker ps | grep n8n

# Verify port binding
docker port n8n

# Test from localhost
curl http://localhost:5678

# Check security group in AWS
# Port 5678 must be open in EC2 security group inbound rules
```

### Out of memory
```bash
# Check memory usage
free -h
docker stats

# Reduce container memory in docker-compose.yml
# Change: memory: 512M → memory: 256M

# Prune execution data
docker exec n8n sqlite3 /home/node/.n8n/database.sqlite \
  "DELETE FROM execution;"
```

### High disk usage
```bash
# Check what's taking space
du -sh n8n-data/*

# Archive and delete old data
tar -czf old_data.tar.gz n8n-data/
rm -rf n8n-data/*
```

---

## 📊 Useful Info Commands

### Docker Version
```bash
docker --version
docker-compose --version
```

### n8n Version
```bash
# From logs
docker logs n8n | grep -i version

# From web UI
Settings → About section
```

### Container IP
```bash
docker inspect n8n | grep -i "ipaddress"
```

### Environment Variables
```bash
docker exec n8n env | grep N8N_
```

---

## 🔐 Security Commands

### Restart with no-network (offline)
```bash
docker-compose up -d --no-recreate
docker network disconnect n8n-network n8n
# Don't do this unless needed!
```

### View running processes in container
```bash
docker exec n8n ps aux
```

### Access container shell
```bash
docker exec -it n8n /bin/bash
# Or
docker exec -it n8n /bin/sh
```

### Test connectivity from container
```bash
docker exec n8n curl https://example.com
docker exec n8n wget -O - https://example.com
```

---

## 📝 Database Commands

### For SQLite (default)
```bash
# Access SQLite database
docker exec n8n sqlite3 /home/node/.n8n/database.sqlite ".tables"

# Backup SQLite database
cp n8n-data/database.sqlite n8n-data/database.sqlite.bak
```

### For PostgreSQL
```bash
# Connect to PostgreSQL
docker exec -it n8n-postgres psql -U n8n -d n8n

# Check database size
docker exec n8n-postgres psql -U n8n -d n8n \
  -c "SELECT pg_size_pretty(pg_database_size('n8n'));"

# Backup PostgreSQL
docker exec n8n-postgres pg_dump -U n8n n8n > backup.sql
```

---

## 🔗 Network & Webhooks

### Test Webhook URL
```bash
# From container
docker exec n8n curl http://localhost:5678/healthz

# From host
curl http://localhost:5678/healthz

# From external (EC2 public IP)
curl http://YOUR_EC2_PUBLIC_IP:5678/healthz
```

### Check listening ports
```bash
# All ports
docker port n8n

# Specific port
sudo netstat -tulpn | grep 5678
```

---

## 📋 Common Issues & Solutions

| Issue | Command |
|-------|---------|
| Container exits | `docker logs n8n` |
| Can't access web | `docker port n8n` & check security group |
| Out of memory | Reduce container memory in docker-compose.yml |
| High disk usage | Prune execution data via UI or SQLite |
| Password forgot | Edit docker-compose.yml, restart |
| Database locked | Restart containers: `docker-compose restart` |
| Slow performance | Check `docker stats`, reduce concurrent executions |

---

## 🎯 Integration with External Services

### Webhook URLs
```
For GitHub/Zapier/etc, use:
http://YOUR_EC2_PUBLIC_IP:5678/webhook/

Example webhook in n8n workflow:
Webhook Trigger → Copy URL → Paste in external service
```

---

## 📞 Support Resources

- **Official Docs**: https://docs.n8n.io/
- **Community Forum**: https://community.n8n.io/
- **Discord**: https://discord.gg/nwekxnxjsi
- **GitHub Issues**: https://github.com/n8n-io/n8n/issues
- **Stack Overflow**: Tag `n8n`

---

## ✅ Pre-Deployment Checklist

- [ ] Docker installed and running
- [ ] docker-compose.yml edited with public IP
- [ ] .env file created with strong password
- [ ] n8n-data directory created
- [ ] Port 5678 open in EC2 security group
- [ ] System has sufficient disk space (20GB+)
- [ ] Backup strategy planned
- [ ] Timezone set correctly in .env

---

## 🎓 Next Steps

1. **First Access**: Login with credentials from .env
2. **Security**: Change default password immediately
3. **Configure**: Set up integrations you need
4. **Test**: Create a test workflow
5. **Backup**: Setup automated backups (cron job)
6. **Monitor**: Monitor resource usage with `docker stats`
7. **Upgrade**: Keep n8n updated monthly

---

**Last Updated**: March 2026 | Ubuntu 22.04 LTS | Docker 20.10+
