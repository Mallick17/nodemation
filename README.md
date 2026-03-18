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
sudo apt install -y curl wget git nano htop certbot
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

## Step 3: Clone the Offiicial n8n Docker Setup Repository

```bash
# Clone the n8n hosting repository
git clone https://github.com/n8n-io/n8n-hosting.git

# Navigate to the Docker Compose with PostgreSQL setup
cd n8n-hosting/docker-compose/withPostgres
``` 

# Self-Signed SSL Setup for n8n - Complete Step-by-Step Walkthrough

## Prerequisites

- ✅ n8n running in Docker Compose
- ✅ Server IP address (e.g., `172.31.46.184`)
- ✅ SSH access to your server
- ✅ OpenSSL available (comes with most Linux distros)

---

## Step-by-Step Execution

### Step 1: SSH into Your Server

```bash
ssh root@YOUR_SERVER_IP
# Example: ssh root@172.31.46.184

# You should see a prompt like: root@ip-172-31-46-184:~#
```

---

### Step 2: Navigate to n8n Directory

```bash
cd ~/n8n-hosting/docker-compose/withPostgres

# Verify you're in the right place
pwd
# Should output: /root/n8n-hosting/docker-compose/withPostgres

# Verify docker-compose.yml exists
ls -la docker-compose.yml
# Should show the file
```

---

### Step 3: Create Certificates Directory

```bash
# Create the certs folder
mkdir -p certs

# Go into it
cd certs

# Verify location
pwd
# Should output: /root/n8n-hosting/docker-compose/withPostgres/certs
```

---

### Step 4: Generate Self-Signed Certificate

**Copy and paste this entire command:**

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes \
  -subj "/C=IN/ST=TamilNadu/L=Chennai/O=MyOrg/CN=$(hostname -I | awk '{print $1}')"
```

**What this does:**
- `-x509` = creates a self-signed certificate
- `-newkey rsa:4096` = generates a 4096-bit RSA key (very secure)
- `-keyout key.pem` = saves the private key
- `-out cert.pem` = saves the certificate
- `-days 365` = certificate valid for 1 year
- `-nodes` = don't encrypt the key (makes Docker mounting easier)
- `-subj` = automatically fills certificate details with your IP

**Expected output:**
```
# No output means success!
# If you get an error, openssl might not be installed
```

---

### Step 5: Verify Certificates Were Created

```bash
# List files
ls -la

# Should show:
# -rw-r--r-- ... cert.pem
# -rw-r--r-- ... key.pem

# View certificate details (optional)
openssl x509 -in cert.pem -text -noout | head -20
```

**Expected output:**
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: ... (some hex number)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = 172.31.46.184
        Subject: CN = 172.31.46.184
```

---

### Step 6: Go Back to Main Directory

```bash
cd ..

# Verify
pwd
# Should output: /root/n8n-hosting/docker-compose/withPostgres

# Verify certs folder exists
ls -la certs/
# Should show cert.pem and key.pem
```

---

### Step 7: Update .env File

Add SSL configuration to your `.env` file:

```bash
cat >> .env << 'EOF'

# ============================================================================
# SSL/TLS Configuration for Self-Signed Certificate
# ============================================================================
N8N_SECURE_COOKIE=true
N8N_PROTOCOL=https
EOF
```

**Verify it was added:**

```bash
cat .env | tail -10
# Should show:
# N8N_SECURE_COOKIE=true
# N8N_PROTOCOL=https
```

---

### Step 8: Update docker-compose.yml File

**This is the most important step!**

Open the file in a text editor:

```bash
nano docker-compose.yml
```

**Find the `n8n:` service section** (around line 40-50)

**Locate the `environment:` section** and add these 4 lines:

```yaml
      - N8N_SECURE_COOKIE=true
      - N8N_PROTOCOL=https
      - N8N_SSL_KEY=/etc/ssl/private/key.pem
      - N8N_SSL_CERT=/etc/ssl/certs/cert.pem
```

**Then find the `volumes:` section** under n8n and add these 2 lines:

```yaml
      - ./certs/cert.pem:/etc/ssl/certs/cert.pem:ro
      - ./certs/key.pem:/etc/ssl/private/key.pem:ro
```

**Your n8n service should look like this:**

```yaml
  n8n:
    image: docker.n8n.io/n8nio/n8n:${N8N_VERSION}
    container_name: n8n-app
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_AUTH_TOKEN=${RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
      - N8N_LOG_LEVEL=info
      # ⬇️ ADD THESE 4 LINES ⬇️
      - N8N_SECURE_COOKIE=true
      - N8N_PROTOCOL=https
      - N8N_SSL_KEY=/etc/ssl/private/key.pem
      - N8N_SSL_CERT=/etc/ssl/certs/cert.pem
    ports:
      - 5678:5678
    volumes:
      - n8n_storage:/home/node/.n8n
      # ⬇️ ADD THESE 2 LINES ⬇️
      - ./certs/cert.pem:/etc/ssl/certs/cert.pem:ro
      - ./certs/key.pem:/etc/ssl/private/key.pem:ro
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - n8n-network
    restart: unless-stopped
```

**Save the file:**
- Press `Ctrl+X`
- Press `Y` (yes)
- Press `Enter` (save)

---

### Step 9: Stop Running Containers

```bash
docker-compose down

# Wait for all containers to stop
sleep 5

# Verify they're stopped
docker-compose ps
# Should show nothing or "no services"
```

---

### Step 10: Start Containers with New Configuration

```bash
docker-compose up -d

# Wait for services to start
sleep 15

# Check status
docker-compose ps
```

**Expected output:**
```
NAME                    IMAGE                  STATUS
withpostgres-postgres-1     postgres:16            Up (healthy)
withpostgres-n8n-1         docker.n8n.io/...      Up
withpostgres-n8n-runner-1  n8nio/runners:...      Up
```

All three should show `Up` (or `Up (healthy)`)

---

### Step 11: Verify HTTPS is Working

**Test the connection:**

```bash
# Test HTTPS with curl
curl -kv https://localhost:5678/ 2>&1 | head -30
```

**Expected output** (first 20 lines):
```
* Host localhost:5678 was resolved.
* Trying 127.0.0.1:5678...
* Connected to localhost (127.0.0.1) port 5678
* SSL certificate problem: self signed certificate
* ...
> GET / HTTP/1.1
```

The important part is:
- ✅ `Connected to localhost (127.0.0.1) port 5678`
- ✅ `SSL certificate problem: self signed certificate` (expected!)

---

### Step 12: Check Logs for Errors

```bash
docker-compose logs n8n | tail -50
```

**Look for:**
- ✅ `n8n ready on`
- ✅ `listening on`
- ✅ No error messages

**If you see errors**, here's how to debug:

```bash
# Get more logs
docker-compose logs n8n | grep -i error

# Or restart and watch live
docker-compose restart n8n
docker-compose logs -f n8n
# Press Ctrl+C to stop watching
```

---

### Step 13: Access n8n in Browser

**Find your server IP:**

```bash
hostname -I | awk '{print $1}'
# Example output: 172.31.46.184
```

**Visit in your browser:**

```
https://172.31.46.184:5678
```

(Replace `172.31.46.184` with your actual server IP)

---

### Step 14: Accept Browser Certificate Warning

When you visit the URL, you'll see a warning:

**Chrome/Edge/Brave:**
1. Click `Advanced`
2. Click `Proceed to 172.31.46.184 (unsafe)` button
3. You'll see the n8n login page! ✅

**Firefox:**
1. Click `Advanced...`
2. Click `Accept the Risk and Continue`
3. You'll see the n8n login page! ✅

**Safari:**
1. Click `Show Details`
2. Click `visit this website` link
3. You'll see the n8n login page! ✅

---

## ✅ Verification Checklist

After completing all steps, verify everything:

```bash
# 1. Certificates exist
ls -la certs/
# Should show: cert.pem and key.pem

# 2. .env has SSL config
grep SECURE_COOKIE .env
# Should show: N8N_SECURE_COOKIE=true

# 3. docker-compose.yml has SSL config
grep -A 5 "N8N_SECURE_COOKIE" docker-compose.yml
# Should show the SSL environment variables

# 4. Containers are running
docker-compose ps
# All three should show "Up"

# 5. HTTPS works
curl -k https://localhost:5678/ | head -20
# Should show HTML content

# 6. Certificate is valid
openssl x509 -in certs/cert.pem -noout -enddate
# Should show: notAfter=Mar 18 09:30:00 2025 GMT
```

---

## 🎉 Success! You're Done!

Your n8n instance is now:
- ✅ Running with HTTPS encryption
- ✅ Secure (even without a domain)
- ✅ Using a self-signed certificate
- ✅ Accessible via `https://YOUR_SERVER_IP:5678`

---

## 📝 What to Do if Something Goes Wrong

### "Connection refused"

```bash
# Check if n8n is running
docker-compose ps

# If not running, start it
docker-compose up -d

# Wait and check logs
sleep 10
docker-compose logs n8n | tail -20
```

### "Still shows HTTP warning"

```bash
# Restart n8n
docker-compose restart n8n

# Wait
sleep 10

# Try again in browser
```

### "Certificate verification error"

This is **normal!** Click "Advanced" → "Proceed anyway" in your browser.

### "Port 5678 is already in use"

```bash
# Check what's using it
netstat -tulpn | grep 5678

# Or stop other services
docker-compose down
docker-compose up -d
```

---

## 🔄 Renewing Certificate After 1 Year

When the certificate expires (after 365 days), regenerate it:

```bash
cd ~/n8n-hosting/docker-compose/withPostgres/certs

# Backup old certificate
cp cert.pem cert.pem.old
cp key.pem key.pem.old

# Generate new certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes \
  -subj "/C=IN/ST=TamilNadu/L=Chennai/O=MyOrg/CN=$(hostname -I | awk '{print $1}')"

# Restart n8n
cd ..
docker-compose restart n8n
sleep 10

echo "✅ Certificate renewed!"
```

---

## 🎯 Summary of Commands

**Complete setup in 60 seconds:**

```bash
# 1. Navigate
cd ~/n8n-hosting/docker-compose/withPostgres

# 2. Create certificates
mkdir -p certs/certs
cd certs
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj "/CN=$(hostname -I | awk '{print $1}')"
cd ..

# 3. Update .env
cat >> .env << 'EOF'

N8N_SECURE_COOKIE=true
N8N_PROTOCOL=https
EOF

# 4. Edit docker-compose.yml (manual step - see above)
nano docker-compose.yml
# Add SSL environment variables and volume mounts

# 5. Restart
docker-compose down
docker-compose up -d
sleep 15

# 6. Done!
echo "Visit: https://$(hostname -I | awk '{print $1}'):5678"
```

---

## 📞 Need Help?

Check these commands:

```bash
# View full logs
docker-compose logs

# Restart n8n
docker-compose restart n8n

# Stop everything
docker-compose down

# Start everything
docker-compose up -d

# Check container health
docker ps

# View certificate info
openssl x509 -in certs/cert.pem -text -noout
```

# n8n Environment Configuration - Manual Setup Guide

## Quick Summary

You need to set these three key variables in `.env`:

```env
N8N_VERSION=2.11.2
RUNNERS_AUTH_TOKEN=<secure-random-token>
POSTGRES_USER=n8n_admin
POSTGRES_NON_ROOT_USER=n8n_app
POSTGRES_PASSWORD=<secure-random-password>
POSTGRES_NON_ROOT_PASSWORD=<secure-random-password>
N8N_ENCRYPTION_KEY=<secure-random-key>
```

---

## Step 1: Generate Secure Tokens (Do This First!)

### Open a terminal on your server:
```bash
# Generate RUNNERS_AUTH_TOKEN (32 bytes, base64)
openssl rand -base64 32
# Example output: xK9mL2pQ8vR5nJ3bT6wF1sH4dG7kM9oP0aZ+cX2yE=
# 👆 Copy this value
```

### Generate N8N_ENCRYPTION_KEY:
```bash
openssl rand -base64 32
# Example output: vT4hM6jL9kP2nR5sW8yD1bG3eJ7qA0xF+cZ2wM5sL=
# 👆 Copy this value
```

### Generate PostgreSQL passwords:
```bash
openssl rand -base64 16
# Example output: K7m9nP2qR4sT6uV8
# 👆 Copy this value (for POSTGRES_PASSWORD)

openssl rand -base64 16
# Example output: M3p7nQ9rS2tU5vW6
# 👆 Copy this value (for POSTGRES_NON_ROOT_PASSWORD)
```

---

## Step 2: Create the .env File

### Navigate to your working directory:
```bash
cd ~/n8n-hosting/docker-compose/withPostgres
pwd  # Verify you're in the right place
```

### Create the .env file with your values:
```bash
cat > .env << 'EOF'
# PostgreSQL Configuration
POSTGRES_USER=n8n_admin
POSTGRES_PASSWORD=K7m9nP2qR4sT6uV8
POSTGRES_DB=n8n
POSTGRES_INITDB_ARGS=-c shared_preload_libraries=pg_stat_statements

# PostgreSQL Non-Root User (what n8n uses)
POSTGRES_NON_ROOT_USER=n8n_app
POSTGRES_NON_ROOT_PASSWORD=M3p7nQ9rS2tU5vW6

# n8n Core Configuration
N8N_VERSION=2.11.2
N8N_ENCRYPTION_KEY=vT4hM6jL9kP2nR5sW8yD1bG3eJ7qA0xF+cZ2wM5sL=
N8N_LOG_LEVEL=info

# n8n Runners Configuration
RUNNERS_AUTH_TOKEN=xK9mL2pQ8vR5nJ3bT6wF1sH4dG7kM9oP0aZ+cX2yE=

# Database Connection
DB_POSTGRESDB_SSL=false
N8N_SECURE_COOKIE=false
EOF
```

> **Replace the values above with your generated tokens!**

---

## Step 3: Verify the .env File

### Check that the file was created:
```bash
ls -la .env
# Should show: -rw------- (600 permissions)
```

### View the contents:
```bash
cat .env
```

### Secure it (important!):
```bash
chmod 600 .env
```
### Fix the permissions
```bash
chmod 644 certs/cert.pem certs/key.pem
```

---

## Step 4: Understanding Each Variable

### RUNNERS_AUTH_TOKEN
- **Purpose**: Authenticates the n8n-runner processes with the main n8n service
- **Generated**: Securely via `openssl rand -base64 32`
- **Length**: 32 bytes (base64) = 44 characters
- **Why**: n8n runners use this token to prove they're legitimate before connecting
- **Same value**: Must be identical in both `n8n` and `n8n-runner` containers

### N8N_VERSION
- **Purpose**: Specifies which Docker image version to pull
- **Value**: `2.11.2` (or your desired version)
- **Recommended**: Keep this pinned to avoid unexpected upgrades
- **Check available versions**: https://hub.docker.com/r/n8nio/n8n/tags

### POSTGRES_USER
- **Purpose**: Root PostgreSQL user (used during database initialization)
- **Value**: `n8n_admin` (you can change this)
- **Used by**: `init-data.sh` to create the non-root user
- **Power level**: Full privileges (create users, databases, etc.)

### POSTGRES_NON_ROOT_USER
- **Purpose**: Limited user that n8n actually uses
- **Value**: `n8n_app` (you can change this)
- **Used by**: n8n application for all database operations
- **Power level**: Limited to the n8n database only
- **Best practice**: Always use a non-root user for applications

### POSTGRES_PASSWORD & POSTGRES_NON_ROOT_PASSWORD
- **Purpose**: Credentials for accessing PostgreSQL
- **Generated**: Securely via `openssl rand -base64 16`
- **Length**: 16 bytes (base64) = 24 characters
- **Security**: Keep these secret! Never commit to git
- **Different values**: Root password ≠ app password (best practice)

### N8N_ENCRYPTION_KEY
- **Purpose**: Encrypts sensitive data in the database (credentials, variables, etc.)
- **Generated**: Securely via `openssl rand -base64 32`
- **CRITICAL**: 
  - ⚠️ Must be set before first startup
  - ⚠️ Changing it later will break decryption
  - ⚠️ Keep it safe and backed up
- **Use case**: All stored credentials are encrypted with this key

---

## Step 5: Restart Services

### Stop existing containers:
```bash
docker-compose down
# Keep volumes (data preserved):
# ✓ docker-compose down  (keeps volumes)
# ✗ docker-compose down -v  (removes volumes = LOST DATA)
```

### Start with new configuration:
```bash
docker-compose up -d
```

### Monitor the startup:
```bash
docker-compose logs -f n8n
# Watch for:
# ✓ "n8n ready on ::, port 5678"
# ✓ "Migrations in progress..."
# ✓ "Editor is now accessible via: http://localhost:5678"
```

### Check all services are healthy:
```bash
docker-compose ps
# Should show:
# postgres-1  Up (healthy)
# n8n-1       Up (running)
# n8n-runner-1 Up (running)
```

---

## Step 6: Verify Everything Works

### From the host machine:
```bash
# Test n8n is accessible
curl http://localhost:5678

# Check runner is registered
docker-compose logs n8n | grep "Registered runner"
# Expected output: "Registered runner "launcher-python""
#                  "Registered runner "launcher-javascript""
```

### From inside the n8n container:
```bash
# Access container shell
docker-compose exec n8n sh

# Inside container - verify environment variables
echo $N8N_VERSION
# Should print: 2.11.2

echo $RUNNERS_AUTH_TOKEN
# Should print: xK9mL2pQ8vR5nJ3bT6wF1sH4dG7kM9oP0aZ+cX2yE=

echo $DB_POSTGRESDB_USER
# Should print: n8n_app

# Verify database connection
node -e "const pg=require('pg'); console.log('PostgreSQL client loaded')"

# Exit container
exit
```

---

## Troubleshooting

### Issue: "RUNNERS_AUTH_TOKEN is not set"
**Solution**: Check that `.env` file exists and has the correct value
```bash
cat .env | grep RUNNERS_AUTH_TOKEN
# Should output: RUNNERS_AUTH_TOKEN=xK9mL2pQ8vR5nJ3bT6wF1sH4dG7kM9oP0aZ+cX2yE=
```

### Issue: "Cannot connect to postgres"
**Solution**: Verify database credentials in `.env` match `init-data.sh`
```bash
docker-compose logs postgres | grep "database system is ready"
# Should show: "database system is ready to accept connections"
```

### Issue: "n8n keeps restarting"
**Solution**: Check logs for specific errors
```bash
docker-compose logs n8n | tail -50
# Look for: "Error", "failed", "refused"
```

### Issue: Runners not connecting
**Solution**: Verify RUNNERS_AUTH_TOKEN is identical in docker-compose.yml
```bash
grep RUNNERS_AUTH_TOKEN docker-compose.yml
grep RUNNERS_AUTH_TOKEN .env
# Both should be identical
```

---

## Security Checklist

- ✅ .env file has `600` permissions (`chmod 600 .env`)
- ✅ .env is NOT committed to git (add to `.gitignore`)
- ✅ All tokens are random (generated with `openssl rand`)
- ✅ Passwords are strong (16+ characters)
- ✅ N8N_ENCRYPTION_KEY is backed up somewhere safe
- ✅ RUNNERS_AUTH_TOKEN is the same in n8n and n8n-runner
- ✅ Different passwords for root and app users

---

## Reference: Variable Locations

Where each variable is used:

```
.env file                  docker-compose.yml           Container
├─ POSTGRES_USER    ──────> environment:               postgres-1
├─ POSTGRES_PASSWORD        POSTGRES_USER              
├─ POSTGRES_DB             POSTGRES_PASSWORD            
├─ POSTGRES_NON_ROOT_USER   POSTGRES_DB                
├─ POSTGRES_NON_ROOT_PASSWORD                          
│                                                       
├─ N8N_VERSION      ──────> image: n8nio/n8n:${N8N_VERSION}
├─ N8N_ENCRYPTION_KEY      environment:               n8n-1
├─ N8N_LOG_LEVEL           DB_POSTGRESDB_USER         
├─ RUNNERS_AUTH_TOKEN      DB_POSTGRESDB_PASSWORD     
└─ DB_POSTGRESDB_SSL       N8N_RUNNERS_AUTH_TOKEN     

    RUNNERS_AUTH_TOKEN ────────────────────────────> n8n-runner-1
                                                       N8N_RUNNERS_AUTH_TOKEN
```

---

## Next Steps

After setup is complete:

1. **Access n8n**: Open http://localhost:5678 in your browser
2. **Create admin user**: Set up your initial login credentials
3. **Test workflow**: Create a simple test workflow
4. **Verify runners**: Check that Python and JavaScript runners are available
5. **Back up encryption key**: Save N8N_ENCRYPTION_KEY to a safe place

---

## Questions?

If something doesn't work:

```bash
# 1. Check logs
docker-compose logs

# 2. Check environment variables
docker-compose config

# 3. Verify all containers are running
docker-compose ps

# 4. Test database connection
docker-compose exec postgres psql -U n8n_admin -d n8n -c "SELECT version();"
```

### 3.1 Review Docker Compose Configuration and Start teh Server

# n8n with PostgreSQL
Starts n8n with PostgreSQL as database.

## Start

To start n8n with PostgreSQL simply start docker-compose by executing the following
command in the current folder.

**IMPORTANT:** But before you do that change the default users and passwords in the [`.env`](.env) file!

```
docker-compose up -d
```

To stop it execute:

```
docker-compose stop
```

## Configuration

The default name of the database, user and password for PostgreSQL can be changed in the [`.env`](.env) file in the current directory.


