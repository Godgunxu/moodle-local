# AWS Deployment Quick Reference

Fast lookup guide for AWS migration files and deployment steps.

## 📑 File Directory

### Documentation (Read in order)

1. **README.md** - Project overview and links
2. **AWS_INFRASTRUCTURE.md** ⭐ **START HERE** - Step-by-step AWS setup
3. **AWS_DEPLOYMENT.md** - Deployment configuration and process
4. **AWS_MIGRATION_GUIDE.md** - Detailed technical guide
5. **MIGRATION_CHECKLIST.md** - Visual checklist for manual deployment

### Configuration Files

| File | Purpose | Action |
|------|---------|--------|
| `.env.example` | Local development template | Used locally |
| `.env.aws.example` | AWS production template | Copy to `.env` on Lightsail |
| `docker-compose.yml` | Local development | Used locally with `docker compose` |
| `docker-compose.dev.yml` | Development reference | Optional, for local testing |
| `docker-compose.aws.yml` | AWS production | Used on Lightsail |

### Deployment Scripts

| Script | Location | Command | When |
|--------|----------|---------|------|
| `verify-aws-config.sh` | Run on Lightsail | `./verify-aws-config.sh` | Before deploying |
| `deploy-aws-v2.sh` | Run on Lightsail | `./deploy-aws-v2.sh` | Initial setup |
| `backup-rds.sh` | Run on Lightsail | `./backup-rds.sh` | Regular backups |
| `setup-ssl.sh` | Run on Lightsail | `./setup-ssl.sh domain.com` | After DNS ready |
| `push-to-github.sh` | Run locally | `./push-to-github.sh` | Version control |

---

## 🚀 Quick Start (3 Steps)

### Step 1: AWS Infrastructure (15 minutes)
```bash
# Follow: AWS_INFRASTRUCTURE.md
# Tasks:
# - Create RDS database
# - Create Lightsail instance
# - Configure security groups
# - Test connectivity
```

### Step 2: Local Preparation (5 minutes)
```bash
# Local machine
cp .env.aws.example .env
nano .env  # Edit with AWS details

# Upload to Lightsail
scp -i key.pem -r moodlehtml ubuntu@IP:~/
scp -i key.pem .env ubuntu@IP:~/moodle-local/
```

### Step 3: Deploy on Lightsail (10 minutes)
```bash
# SSH into Lightsail
ssh -i key.pem ubuntu@IP

# Verify configuration
cd ~/moodle-local
chmod +x verify-aws-config.sh
./verify-aws-config.sh

# Deploy
chmod +x deploy-aws-v2.sh
./deploy-aws-v2.sh
```

---

## 📊 Architecture Diagram

```
Local Machine (Your Computer)
├── moodlehtml/           (Moodle source code)
├── .env                  (Created from .env.aws.example)
├── docker-compose.yml    (Local dev only)
└── Scripts (for running locally)
    ├── push-to-github.sh
    └── setup-ssl.sh (optional)

                    ↓ Upload via SCP

AWS Lightsail Instance (Ubuntu 22.04)
├── moodlehtml/           (Synced from local)
├── .env                  (Configuration)
├── docker-compose.yml    (From docker-compose.aws.yml)
└── Moodle Container
    ├── Apache (Port 80/443)
    └── PHP 8.1

                    ↓ Connects to

AWS RDS MariaDB
├── Database: moodle
├── User: moodle
├── Backups: 7-day retention
└── Encryption: Enabled

                    ↓ DNS Points to

AWS Route 53 (Optional) or Your Domain Registrar
└── yourdomain.com → Lightsail IP
```

---

## 🔄 Complete Workflow

### Hours 1-2: Infrastructure Setup
1. Create AWS account (if needed)
2. Create RDS MariaDB database
3. Create Lightsail instance
4. Configure security groups
5. Test RDS connection

**Output:** RDS endpoint, Lightsail IP, SSH key

### Hours 2-3: Local Preparation
1. Copy `.env.aws.example` to `.env`
2. Edit `.env` with AWS details
3. Upload files to Lightsail
4. Verify files received

**Output:** Files ready on Lightsail

### Hour 3: Deployment
1. SSH into Lightsail
2. Run `verify-aws-config.sh`
3. Run `deploy-aws-v2.sh`
4. Complete Moodle installer
5. Test access

**Output:** Moodle running on AWS

### Hour 4: Post-Deployment
1. Setup DNS (if using domain)
2. Setup SSL certificate
3. Configure backups
4. Monitor and test

**Output:** Production-ready Moodle

---

## ✅ Verification Checklist

### Before AWS Setup
- [ ] AWS account created
- [ ] AWS region chosen (us-east-1 recommended)
- [ ] Domain purchased (optional)

### After Infrastructure Setup
- [ ] RDS database is "Available"
- [ ] Lightsail instance is "Running"
- [ ] Static IP attached
- [ ] Security groups configured
- [ ] Can SSH to Lightsail
- [ ] Can connect to RDS from Lightsail

### Before Deployment
- [ ] .env file created with correct values
- [ ] Moodle files uploaded to Lightsail
- [ ] Scripts uploaded and executable
- [ ] `verify-aws-config.sh` reports no errors

### After Deployment
- [ ] Docker containers running (`docker compose ps`)
- [ ] Moodle accessible via HTTP
- [ ] Database connection working
- [ ] SSL certificate working (if configured)

---

## 📚 Configuration Reference

### Minimal .env (Required)
```env
RDS_ENDPOINT=moodle-db.xxxxx.region.rds.amazonaws.com
DB_NAME=moodle
DB_USER=moodle
DB_PASSWORD=StrongPassword123!
MOODLE_URL=https://yoursite.com
SITE_NAME=My Moodle
ADMIN_EMAIL=admin@yoursite.com
AWS_REGION=us-east-1
```

### Optional .env Variables
```env
# SSL/HTTPS
LETSENCRYPT_DOMAIN=yoursite.com
LETSENCRYPT_EMAIL=admin@yoursite.com

# PHP Settings
PHP_MAX_MEMORY=256M
UPLOAD_MAX_FILESIZE=100M

# Backups
AWS_BACKUP_BUCKET=moodle-backups
BACKUP_FREQUENCY=daily
```

---

## 🆘 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| RDS connection fails | See AWS_INFRASTRUCTURE.md Step 3 |
| Cannot SSH to Lightsail | Check SSH key permissions and security group |
| Deployment fails | Run `verify-aws-config.sh` first |
| 403 Forbidden error | Check file permissions in docker-compose logs |
| Database backup fails | Verify RDS credentials and endpoint |
| SSL not working | Check certificate with `sudo certbot certificates` |

---

## 💰 Cost Tracking

| Item | Monthly | Annual | Notes |
|------|---------|--------|-------|
| Lightsail 512MB | $3.50 | $42 | Minimum |
| RDS db.t3.micro | $0 (free yr 1) | $15-20 | After free tier |
| Data transfer | $0-5 | $0-60 | Usually minimal |
| Domain | $0 | $12 | Already purchased |
| **Total** | **$3.50-8.50** | **$70-140** | Highly profitable |

---

## 📞 Getting Help

### Documentation
- Read **AWS_INFRASTRUCTURE.md** for step-by-step AWS setup
- Read **AWS_DEPLOYMENT.md** for deployment instructions
- Check **MIGRATION_CHECKLIST.md** for visual guide

### Debugging
```bash
# 1. Check container status
docker compose ps

# 2. View logs
docker compose logs -f

# 3. Test database
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASSWORD -e "SELECT 1"

# 4. Test connectivity
docker compose exec moodle curl http://localhost/
```

### Common Issues
See AWS_MIGRATION_GUIDE.md → Troubleshooting section

---

## 🎯 Next Steps

1. **Right Now**: Read AWS_INFRASTRUCTURE.md
2. **Next 30 min**: Complete AWS infrastructure setup
3. **Next Hour**: Prepare and upload files
4. **Next 2 Hours**: Deploy on Lightsail
5. **Next 4 Hours**: Setup SSL and backups
6. **Ongoing**: Monitor and maintain

---

## 📋 File Checklist

Essential files for AWS migration:

```
✓ .env.aws.example          (Template)
✓ .env.example              (Local template)
✓ docker-compose.yml        (Local)
✓ docker-compose.aws.yml    (Production)
✓ docker-compose.dev.yml    (Development)
✓ moodlehtml/               (Source code, ~464MB)
✓ migration-backup/         (Backups, if migrating)

Scripts:
✓ deploy-aws-v2.sh          (Main deployment)
✓ verify-aws-config.sh      (Config validation)
✓ backup-rds.sh             (Database backups)
✓ setup-ssl.sh              (SSL/HTTPS)
✓ deploy-to-aws.sh          (Legacy, use v2)
✓ setup-ssl.sh              (Legacy, still works)

Documentation:
✓ README.md                 (Overview)
✓ AWS_INFRASTRUCTURE.md     (⭐ Start here)
✓ AWS_DEPLOYMENT.md         (Deployment guide)
✓ AWS_MIGRATION_GUIDE.md    (Technical details)
✓ MIGRATION_CHECKLIST.md    (Visual checklist)
✓ AWS_QUICK_REFERENCE.md    (This file)
```

---

## 🔐 Security Reminders

- [ ] Never commit `.env` file to git
- [ ] Use strong passwords (12+, mixed case, numbers, symbols)
- [ ] Rotate passwords every 90 days
- [ ] Enable RDS encryption
- [ ] Restrict Lightsail firewall to your IP for SSH
- [ ] Backup regularly and test restoration
- [ ] Monitor CloudWatch logs
- [ ] Keep Docker images updated
- [ ] Use HTTPS/SSL for all connections
- [ ] Enable AWS MFA for account security

---

**Version:** 2.0
**Updated:** February 16, 2026
**Tested On:** Ubuntu 22.04 LTS, AWS Lightsail, AWS RDS MariaDB 10.11
