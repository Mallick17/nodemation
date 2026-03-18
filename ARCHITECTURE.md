# n8n Docker Architecture & Deployment Diagram

## 🏗️ System Architecture (SQLite Version)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS EC2 Instance                                 │
│                  (Ubuntu 22.04 LTS - t3.micro)                           │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                      Docker Container                              │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │                    n8n Application                            │ │  │
│  │  │  (Node.js-based workflow automation)                         │ │  │
│  │  │                                                               │ │  │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │                                                        │ │ │  │
│  │  │  │              Workflow Editor UI                        │ │ │  │
│  │  │  │         (Accessible at :5678)                         │ │ │  │
│  │  │  │         - Create workflows                            │ │ │  │
│  │  │  │         - Connect integrations                        │ │ │  │
│  │  │  │         - Monitor executions                          │ │ │  │
│  │  │  │                                                        │ │ │  │
│  │  │  └────────────────────────────────────────────────────────┘ │ │  │
│  │  │                          ↓                                   │ │  │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │              Execution Engine                           │ │ │  │
│  │  │  │  - Runs workflows                                       │ │ │  │
│  │  │  │  - Manages credentials                                 │ │ │  │
│  │  │  │  - Handles webhooks                                    │ │ │  │
│  │  │  └────────────────────────────────────────────────────────┘ │ │  │
│  │  │                          ↓                                   │ │  │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │         SQLite Database                                 │ │ │  │
│  │  │  │  (/home/node/.n8n/database.sqlite)                     │ │ │  │
│  │  │  │  - Workflows                                           │ │ │  │
│  │  │  │  - Credentials (encrypted)                            │ │ │  │
│  │  │  │  - Execution history                                  │ │ │  │
│  │  │  │  - Settings & metadata                                │ │ │  │
│  │  │  └────────────────────────────────────────────────────────┘ │ │  │
│  │  │                                                               │ │  │
│  │  │  Port Mapping:                                               │ │  │
│  │  │  Container :5678 → Host :5678                              │ │  │
│  │  │                                                               │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  │                                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                   Data Persistence (Volumes)                       │  │
│  │                                                                    │  │
│  │  ~/n8n/n8n-data/                                                 │  │
│  │  ├── database.sqlite         ← SQLite database file             │  │
│  │  ├── .n8n/                   ← n8n configuration                │  │
│  │  │   ├── encryption.key      ← Credential encryption           │  │
│  │  │   ├── credentials/        ← Stored credentials              │  │
│  │  │   └── workflow-data/      ← Workflow templates              │  │
│  │  └── logs/                   ← Application logs                 │  │
│  │                                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              External Network Access                              │  │
│  │                                                                    │  │
│  │  - EC2 Security Group allows inbound TCP:5678                   │  │
│  │  - Public IP addresses HTTP traffic to port 5678               │  │
│  │  - Webhooks from external services routed to n8n               │  │
│  │                                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

                              ↓ HTTP Requests ↓

┌─────────────────────────────────────────────────────────────────────────┐
│                     External Services                                    │
│                                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │  GitHub  │  │  Slack   │  │  Gmail   │  │  Other   │               │
│  │  Webhooks│  │  Messages│  │  SMTP    │  │ Services │               │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘               │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Production Architecture (PostgreSQL Version)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS EC2 Instance                                 │
│                  (Ubuntu 22.04 LTS - t3.micro)                           │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Docker Network (n8n-network)                    │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────┐      ┌─────────────────────────┐   │  │
│  │  │   n8n Application       │      │  PostgreSQL Database    │   │  │
│  │  │   Container             │      │  Container              │   │  │
│  │  │                         │      │                         │   │  │
│  │  │  Port: 5678             │      │  Port: 5432             │   │  │
│  │  │                         │      │  (Internal only)        │   │  │
│  │  │  ┌──────────────────┐  │      │  ┌─────────────────┐   │   │  │
│  │  │  │  Workflow Editor │  │      │  │  PostgreSQL     │   │   │  │
│  │  │  │  & Execution     │  │      │  │  Database       │   │   │  │
│  │  │  └──────────────────┘  │      │  │                 │   │   │  │
│  │  │           ↓             │      │  │ ┌─────────────┐ │   │   │  │
│  │  │  ┌──────────────────┐  │      │  │ │ Workflows   │ │   │   │  │
│  │  │  │ Credential Store │◄──────────►├─│ Executions  │ │   │   │  │
│  │  │  │ (Encrypted)      │  │      │  │ │ Credentials │ │   │   │  │
│  │  │  └──────────────────┘  │      │  │ │ History     │ │   │   │  │
│  │  │                         │      │  │ └─────────────┘ │   │   │  │
│  │  │  Mount:                 │      │  │                 │   │   │  │
│  │  │  /home/node/.n8n        │      │  │ Volume:         │   │   │  │
│  │  │                         │      │  │ postgres_data   │   │   │  │
│  │  └─────────────────────────┘      │  └─────────────────┘   │   │  │
│  │                                    │                         │   │  │
│  │  Volume: n8n_data                 │                         │   │  │
│  │  ├── .n8n/                        │                         │   │  │
│  │  │   ├── encryption.key           │                         │   │  │
│  │  │   └── credentials/             │                         │   │  │
│  │  └── logs/                        │                         │   │  │
│  │                                    │                         │   │  │
│  │  └─────────────────────────────────┴─────────────────────────┘   │  │
│  │                                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 File Structure

```
~/n8n/
│
├── 📄 README.md                          ← Start here
├── 📄 n8n_docker_setup_guide.md          ← Complete guide
├── 📄 QUICK_REFERENCE.md                 ← Command reference
│
├── ⚙️ docker-compose.yml                 ← SQLite config (use this first)
├── ⚙️ docker-compose-postgres.yml        ← PostgreSQL config (production)
├── ⚙️ .env                               ← Your configuration (KEEP SECRET!)
├── ⚙️ .env.template                      ← Template reference
│
├── 🔧 n8n-manager.sh                     ← Management automation script
│
├── 📁 n8n-data/                          ← Data persistence
│   ├── database.sqlite                   ← SQLite database
│   ├── .n8n/                             ← n8n internal config
│   │   ├── encryption.key
│   │   ├── credentials/
│   │   └── ...
│   └── logs/
│
├── 📁 backups/                           ← Backup archives
│   ├── n8n_backup_20240301_120000.tar.gz
│   ├── n8n_backup_20240302_120000.tar.gz
│   └── ...
│
└── 📄 n8n-manager.log                    ← Operation logs

```

---

## 🔄 Data Flow Diagram

### Simple Workflow Execution

```
┌────────────────────┐
│  External Service  │  (GitHub, Slack, API, etc.)
│   (Webhook Call)   │
└──────────┬─────────┘
           │
           │ HTTP POST
           ↓
┌────────────────────────────────────────┐
│      n8n Webhook Trigger Node          │
│  (Receives webhook from external service)
└──────────┬─────────────────────────────┘
           │
           │ Parse & Validate
           ↓
┌────────────────────────────────────────┐
│      Workflow Logic Nodes              │
│  (Process, transform, conditional)     │
└──────────┬─────────────────────────────┘
           │
           │ Execute Actions
           ↓
┌────────────────────────────────────────┐
│    Action Nodes (API, Database, etc.)  │
│  (Create issue, send message, etc.)    │
└──────────┬─────────────────────────────┘
           │
           │ Store Execution Record
           ↓
┌────────────────────────────────────────┐
│      SQLite / PostgreSQL Database      │
│  (Logs execution history & status)     │
└────────────────────────────────────────┘
```

---

## 🚀 Deployment Process

```
┌─────────────────────────────────────────────────────────────┐
│                   START: System Setup                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  1. SSH into EC2 Instance    │
        │     (Ubuntu 22.04 LTS)       │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  2. Install Docker           │
        │     - Docker Engine          │
        │     - Docker Compose         │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  3. Create ~/n8n Directory   │
        │     - Copy files             │
        │     - Create n8n-data/       │
        │     - Create backups/        │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  4. Configure .env File      │
        │     - Set password           │
        │     - Set public IP          │
        │     - Set timezone           │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  5. Choose Configuration     │
        │     - SQLite (simple)        │
        │     - PostgreSQL (advanced)  │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  6. Pull Docker Images       │
        │     docker-compose pull      │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  7. Start n8n               │
        │     docker-compose up -d     │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  8. Verify Startup           │
        │     - Check logs             │
        │     - Wait for health checks │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  9. Configure Security       │
        │     - Security group rules   │
        │     - Change password        │
        │     - Enable backups         │
        └──────────────┬───────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │  10. Access Web Interface    │
        │  http://YOUR_IP:5678         │
        └──────────────┬───────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              SUCCESS: n8n is Running! 🎉                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Data Security & Encryption

```
┌─────────────────────────────────────────────┐
│   Sensitive Credentials in n8n             │
│                                             │
│  ┌────────────────────────────────────┐   │
│  │  API Keys, Tokens, Passwords       │   │
│  │  (Database, GitHub, Slack, etc.)   │   │
│  └─────────────┬──────────────────────┘   │
│                │                           │
│                │ Encrypt with              │
│                ↓ encryption.key            │
│  ┌─────────────────────────────────────┐  │
│  │  Encrypted Credentials              │  │
│  │  (Stored in Database)               │  │
│  │                                      │  │
│  │  Example (encrypted):                │  │
│  │  "aW5jLy9mWGx3eWVpMGsxL..."       │  │
│  └─────────────────────────────────────┘  │
│                                             │
│  ⚠️ If encryption.key is lost:             │
│     - All credentials become inaccessible │
│     - Backup MUST be restored              │
│     - Regular backups are CRITICAL        │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 📊 Resource Usage Pattern

```
Memory Usage (typical t3.micro):
┌────────────────────────────────────────────┐
│ 1 GB Total RAM                              │
├────────────────────────────────────────────┤
│                                             │
│ n8n Container:  300-400 MB (idle)          │
│ PostgreSQL:     150-200 MB (optional)       │
│ System:         200-300 MB                  │
│ Free:           50-150 MB                   │
│                                             │
└────────────────────────────────────────────┘

Disk Usage Pattern:
┌────────────────────────────────────────────┐
│ 20 GB Total Storage                         │
├────────────────────────────────────────────┤
│                                             │
│ OS & Docker:    2-3 GB                      │
│ n8n Database:   100-500 MB                  │
│ Execution Data: 1-5 GB (grows over time)   │
│ Backups:        2-5 GB (keep 7 days)       │
│ Free Space:     5-10 GB (minimum safe)     │
│                                             │
│ ⚠️ Need to prune old executions regularly! │
│                                             │
└────────────────────────────────────────────┘
```

---

## 🔄 Backup & Recovery Strategy

```
Daily Operations:
┌─────────────────────────────────────────┐
│  Create Workflow                         │
│  ↓                                       │
│  Save & Test                             │
│  ↓                                       │
│  Activate Workflow                       │
│  ↓                                       │
│  Run Executions                          │
└────────────────┬────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────┐
│  Daily Backup (2 AM via Cron)            │
│  - tar.gz database                       │
│  - Store in backups/                     │
│  - Keep 7 days                           │
└────────────────┬────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ↓                 ↓
  ┌──────────┐      ┌──────────┐
  │ Normal   │      │ Disaster │
  │ Restore  │      │ Recovery │
  │ (Manual) │      │ (Auto)   │
  └──────────┘      └──────────┘
        │                │
        ↓                ↓
  Restore File    Restore Last
  to new system   Known Good


Backup Schedule:
┌─────────────────────────────────────────┐
│  Week 1  →  Keep all backups            │
│  Week 2  →  Keep 3 most recent          │
│  Week 3  →  Keep 2 most recent          │
│  Week 4+ →  Delete old backups          │
│                                          │
│  Separate Archive (Monthly):             │
│  - Store externally (off-site)           │
│  - AWS S3, GitHub releases, etc.        │
│  - For long-term retention               │
│                                          │
└─────────────────────────────────────────┘
```

---

## 🌐 Network & Security Diagram

```
                    Internet
                       │
                       │ HTTP:5678
                       ↓
        ┌──────────────────────────────┐
        │  AWS Security Group           │
        │  Rules:                       │
        │  ✓ Allow TCP:5678 from ::/0  │
        │  ✓ Allow SSH:22 from MY_IP   │
        └────────────┬─────────────────┘
                     │
                     ↓
        ┌──────────────────────────────┐
        │  EC2 Instance Network         │
        │  (Internal only)              │
        │                               │
        │  eth0: Public IP (5678)      │
        │  eth0: Private IP (internal) │
        └────────────┬─────────────────┘
                     │
                     ↓
        ┌──────────────────────────────┐
        │  Docker Bridge Network       │
        │  (n8n-network)               │
        │                               │
        │  n8n:5678                    │
        │  postgres:5432 (if used)     │
        └──────────────────────────────┘


Webhook Flow:
┌─────────────────────────────────────┐
│  External Service (GitHub, etc.)     │
│  Sends webhook to:                   │
│  http://YOUR_IP:5678/webhook/...    │
└──────────────┬──────────────────────┘
               │
               │ HTTP POST
               ↓
┌─────────────────────────────────────┐
│  EC2 Security Group                  │
│  ✓ Port 5678 open                   │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  Docker Container                    │
│  Receives webhook                    │
│  Triggers workflow execution         │
└─────────────────────────────────────┘
```

---

## 🚨 Monitoring & Alerts

```
                 n8n Running
                      │
         ┌────────────┼────────────┐
         │            │            │
         ↓            ↓            ↓
    ┌─────────┐ ┌──────────┐ ┌─────────┐
    │ Logs    │ │ Resource │ │Execution│
    │ Monitor │ │  Monitor │ │ Monitor │
    └────┬────┘ └────┬─────┘ └────┬────┘
         │           │            │
    ┌────┴───────────┴────────────┴─────┐
    │                                    │
    │  Issue Detected?                  │
    │                                    │
    ├─ Memory > 90%? → Prune data      │
    ├─ Disk > 90%?   → Prune data      │
    ├─ Workflow fail?→ Check logs      │
    ├─ No IP access? → Check security  │
    │                                    │
    └────────────────────────────────────┘
```

---

## 📈 Growth & Scaling Considerations

```
Current (t3.micro with SQLite):
┌──────────────────────────────┐
│ ✓ Single workflow execution   │
│ ✓ Simple integrations         │
│ ✓ < 1000 executions/day      │
│ ✓ Manual data pruning         │
│ ✓ Development/testing         │
└──────────────────────────────┘
        │ Need to scale? │
        │ Add features?  │
        ↓
    ┌─────────────────────────────────┐
    │ Upgrade Scenario 1: PostgreSQL  │
    │ (Still on t3.micro)             │
    │                                  │
    │ Benefits:                        │
    │ ✓ Better performance            │
    │ ✓ Handles more concurrent tasks │
    │ ✓ Advanced features enabled     │
    └─────────────────────────────────┘
        │
        ↓
    ┌─────────────────────────────────┐
    │ Upgrade Scenario 2: t3.small     │
    │ (From t3.micro)                 │
    │                                  │
    │ Benefits:                        │
    │ ✓ 2 GB RAM (4x more)            │
    │ ✓ Better performance            │
    │ ✓ Handle more workflows         │
    │ ✓ Smoother execution            │
    └─────────────────────────────────┘
        │
        ↓
    ┌─────────────────────────────────┐
    │ Upgrade Scenario 3: t3.medium    │
    │ (For production)                │
    │                                  │
    │ Benefits:                        │
    │ ✓ 4 GB RAM                      │
    │ ✓ 2 vCPUs                       │
    │ ✓ Queue mode possible           │
    │ ✓ Multiple workers              │
    │ ✓ High availability possible    │
    └─────────────────────────────────┘
```

---

## 🎯 File Relationships

```
Your Configuration:
    .env  ←─────────────┐
     │                  │ Loaded by
     ↓                  │
docker-compose.yml ────┴──→ Docker Container Start
     │
     ├─ references → n8n Docker image
     ├─ mounts → n8n-data/ directory
     └─ exposes → port 5678

Automation:
    n8n-manager.sh
         │
         ├─→ Uses docker-compose.yml
         ├─→ References .env for config
         ├─→ Creates/manages backups/
         └─→ Provides CLI interface

Documentation:
    README.md
         │
         ├─→ Points to setup guide
         ├─→ References quick guide
         └─→ Explains all files

Setup Guide:
    n8n_docker_setup_guide.md
         │
         ├─→ Detailed explanation
         ├─→ Step-by-step instructions
         └─→ Troubleshooting help

Quick Reference:
    QUICK_REFERENCE.md
         │
         ├─→ Common commands
         ├─→ Quick troubleshooting
         └─→ Command examples
```

---

**Diagram Version**: March 2026
**Architecture**: Optimized for AWS EC2 t3.micro
**Database Options**: SQLite (default) + PostgreSQL (scalable)
