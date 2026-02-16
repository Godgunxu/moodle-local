# Moodle to AWS Lightsail Migration - Quick Start Checklist

## 📋 Pre-Migration (Local Machine)

- [ ] **Database Backup**: `sudo docker exec moodle-db mariadb-dump -uroot -prootpass moodle > migration-backup/moodle_backup.sql`
- [ ] **Create Migration Package**: 
  ```bash
  tar -czf moodle-migration.tar.gz moodlehtml/ migration-backup/
  ls -lh moodle-migration.tar.gz  # Should be 1-2GB
  ```
- [ ] **Have AWS Account Ready**: https://aws.amazon.com
- [ ] **Have Domain Ready**: Whatever domain you want to use
- [ ] **Note Your RDS Settings**: Will use `moodle` user (NOT moodlepass for production!)

---

## 🏗️ AWS Infrastructure (5-15 minutes)

### Create RDS Database

1. **AWS Console** → **RDS** → **Databases** → **Create Database**
   - [ ] Engine: **MariaDB 10.11**
   - [ ] DB Instance Identifier: **moodle-db**
   - [ ] Master Username: **moodle**
   - [ ] Master Password: **!GenerateStrongPassword!** ← Save this
   - [ ] Public Accessibility: **NO** (we'll allow from Lightsail only)
   - [ ] Enable backups: **Yes**, 7 days
   - [ ] Create Database

2. **Note your RDS Endpoint**: 
   - After creation, go to **Connectivity** tab
   - Copy the **Writer endpoint** (looks like: `moodle-db.c9akciq32.us-east-1.rds.amazonaws.com`)

---

### Create Lightsail Instance

1. **AWS Lightsail** → **Create Instance**
   - [ ] **Location**: Same region as RDS
   - [ ] **Platform**: Linux/Unix
   - [ ] **Blueprint**: Ubuntu 22.04 LTS
   - [ ] **Plan**: **$3.50/month** (512 MB RAM)
   - [ ] Create Instance

2. **Configure Lightsail**:
   - [ ] Click your instance
   - [ ] **Networking** → **Create static IP** → Choose "ATTACH"
   - [ ] Note your **Static IP Address**

---

### Security Configuration

1. **RDS Security Group**:
   - [ ] RDS Console → Your database → **VPC security groups** → Click security group
   - [ ] **Inbound Rules** → **Edit**
   - [ ] Add rule: 
     - Type: **MySQL/Aurora**
     - Port: **3306**
     - Source: **Lightsail security group** (search by name)
   - [ ] **Save**

2. **Lightsail Security Group**:
   - [ ] Lightsail Console → Instance → **Networking**
   - [ ] Click the firewall/security group name
   - [ ] Add rules (if not already there):
     - [ ] HTTP (80): From **0.0.0.0/0**
     - [ ] HTTPS (443): From **0.0.0.0/0**
     - [ ] SSH (22): From **YOUR_IP_ONLY** (for security)

---

## 🚀 Deploy to Lightsail (10 minutes)

### SSH into Lightsail

```bash
# From AWS Lightsail console, click "Connect" (uses browser terminal)
# OR use SSH key:
ssh -i /path/to/lightsail-key.pem ubuntu@<YOUR_STATIC_IP>
```

### Upload Files

**Option A: Using Browser Terminal** (easiest):
1. Lightsail Console → Your Instance
2. Click **Upload file** → Select `moodle-migration.tar.gz`

**Option B: Using SCP** (from your local machine):
```bash
scp -i /path/to/lightsail-key.pem moodle-migration.tar.gz ubuntu@<YOUR_STATIC_IP>:~/
```

### Run Deployment Script

```bash
# SSH into Lightsail (if not already there)

# Download and run deployment script
curl -O https://raw.github.com/your-repo/deploy-to-aws.sh
chmod +x deploy-to-aws.sh
./deploy-to-aws.sh

# Script will ask for:
# - RDS Endpoint (paste the long one, e.g., moodle-db.c9akciq32.us-east-1.rds.amazonaws.com)
# - RDS Password (the strong one you created)
# - Your Domain (e.g., moodle.yourdomain.com or just yourdomain.com)
# - Admin Email
```

---

## 🌐 Domain & SSL Setup (5 minutes)

### Update DNS

1. **Go to Your Domain Registrar** (GoDaddy, Namecheap, Route 53, etc.)
2. **DNS Settings** → Find **A Record**
3. **Create/Update A Record**:
   - [ ] Name: **@** (or leave blank for root)
   - [ ] Type: **A**
   - [ ] Value: **Your Lightsail Static IP**
   - [ ] TTL: **3600** (or lower for faster updates)
   - [ ] Save

4. **Test DNS** (wait 5-10 minutes):
   ```bash
   # From your local machine
   nslookup yourdomain.com
   # Should show your Lightsail IP
   ```

### Setup SSL Certificate

SSH into Lightsail:

```bash
chmod +x setup-ssl.sh
./setup-ssl.sh yourdomain.com

# Script will:
# 1. Install Let's Encrypt Certbot
# 2. Generate free SSL certificate
# 3. Configure auto-renewal
# 4. Restart Moodle with HTTPS
```

---

## ✅ Verification

### Check Everything Works

```bash
# SSH into Lightsail
docker compose ps          # Check all containers running
docker compose logs -f     # Watch logs
curl http://localhost      # Should work

# Test database
docker compose exec moodle mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> -e "SELECT 1"
# Should return: 1
```

### Access Your Moodle

1. **Browser**: Open `https://yourdomain.com`
2. **Should see**: Moodle login page
3. **Log in** with admin credentials from your backup
4. **Test**:
   - [ ] Can you login?
   - [ ] Can you see your courses?
   - [ ] Can you upload files?

---

## 🔄 Post-Migration Setup

### Set Up Automated Backups

SSH into Lightsail:

```bash
# Create backup directory
mkdir -p ~/backups

# Create backup script
cat > ~/backup-moodle.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/backups"
mkdir -p $BACKUP_DIR

# Database backup
mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> moodle | gzip > $BACKUP_DIR/db_$(date +%Y%m%d_%H%M%S).sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "*.gz" -mtime +30 -exec rm {} \;

echo "Backup complete"
EOF

chmod +x ~/backup-moodle.sh

# Schedule daily at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * ~/backup-moodle.sh") | crontab -
```

### Monitor Performance

```bash
# Check Docker stats
watch docker stats

# Check disk space
df -h

# Check memory
free -h
```

---

## 🆘 Troubleshooting

### Can't Access Moodle (403 Forbidden)

```bash
# Fix file permissions in Lightsail
cd ~/moodlehtml
sudo chown -R 33:33 .
sudo chmod -R 755 .
docker compose restart moodle
```

### Database Connection Error

```bash
# Test connection from Lightsail
docker compose exec moodle mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> -e "SELECT 1"

# If fails:
# 1. Check RDS security group allows port 3306
# 2. Verify RDS is in same region as Lightsail
# 3. Check password is correct
```

### HTTPS/SSL Not Working

```bash
# Check certificate
sudo certbot certificates

# Manually renew if needed
sudo certbot renew --force-renewal

# Check logs
docker compose logs moodle | grep -i ssl
```

### Can't SSH into Lightsail

```bash
# From Lightsail console, click "Connect"
# Uses browser-based terminal
# Or check firewall allows your IP on port 22
```

---

## 💰 Cost Summary

| Component | Monthly Cost |
|-----------|-------------|
| Lightsail (512 MB) | $3.50 |
| RDS MariaDB | Free (first 12 months) or ~$15 |
| Data Transfer | $0-5 |
| Domain | ~$12/year ($1/month) |
| **Total** | ~$4-20/month |

---

## 📚 Important Files

In your `/home/jason/Downloads/moodle-local/` directory:

- [ ] `AWS_MIGRATION_GUIDE.md` - Detailed step-by-step guide
- [ ] `deploy-to-aws.sh` - Automated deployment script
- [ ] `setup-ssl.sh` - SSL certificate setup script
- [ ] `docker-compose.yml` - Original local configuration
- [ ] `moodlehtml/` - Moodle source code (1-2 GB)
- [ ] `migration-backup/moodle_backup.sql` - Database backup
- [ ] `docker-compose-aws.yml` - AWS-specific configuration (reference)

---

## 🎯 Next Steps

1. **TODAY**: Follow this checklist
2. **DAY 1-2**: Wait for DNS propagation
3. **DAY 3**: Verify everything works
4. **DAY 4+**: Invite users to migrate
5. **DECOMMISSION**: After everyone migrated, remove local Docker setup

---

## ❓ Quick Reference

**Lightsail IP**: ___________________  
**RDS Endpoint**: ___________________  
**Domain**: ___________________  
**Admin Email**: ___________________  

Save this checklist with these details filled in!

---

## 📞 Support Resources

- AWS Lightsail Docs: https://docs.aws.amazon.com/lightsail/
- AWS RDS Docs: https://docs.aws.amazon.com/rds/
- Moodle Documentation: https://docs.moodle.org
- Certbot Documentation: https://certbot.eff.org/
- Docker Documentation: https://docs.docker.com/
