# AWS Deployment Guide for Moodle

Complete deployment instructions for migrating Moodle to AWS Lightsail with RDS database.

## Quick Start (3 Steps)

### Step 1: Prepare Configuration
```bash
# Copy the AWS template to .env
cp .env.aws.example .env

# Edit .env with your AWS details
nano .env
# Set: RDS_ENDPOINT, DB_PASSWORD, MOODLE_URL, SITE_NAME, ADMIN_EMAIL
```

### Step 2: Upload to Lightsail
```bash
# On your local machine
# 1. Create Lightsail instance (Ubuntu 22.04)
# 2. Get Lightsail static IP
# 3. Upload files:

scp -i your-lightsail-key.pem -r moodlehtml ubuntu@LIGHTSAIL_IP:~/
scp -i your-lightsail-key.pem .env ubuntu@LIGHTSAIL_IP:~/moodle-local/
```

### Step 3: Deploy on Lightsail
```bash
# SSH into Lightsail
ssh -i your-lightsail-key.pem ubuntu@LIGHTSAIL_IP

# Navigate to deployment directory
cd ~/path-to-project

# Run verification
chmod +x verify-aws-config.sh
./verify-aws-config.sh

# Run deployment
chmod +x deploy-aws-v2.sh
./deploy-aws-v2.sh
```

---

## File Reference

### Configuration Files

| File | Purpose | Action |
|------|---------|--------|
| `.env.aws.example` | AWS configuration template | Copy to `.env` and edit |
| `docker-compose.aws.yml` | AWS production config | Used by deployment script |
| `docker-compose.dev.yml` | Local development config | For testing locally |

### Deployment Scripts

| Script | Purpose | When to Use |
|--------|---------|------------|
| `deploy-aws-v2.sh` | Main AWS deployment | Initial setup on Lightsail |
| `verify-aws-config.sh` | Validate configuration | Before running deploy script |
| `backup-rds.sh` | Backup RDS database | Regular backups (add to cron) |
| `setup-ssl.sh` | Configure HTTPS | After domain DNS is set |

### Supporting Files

| File | Purpose |
|------|---------|
| `AWS_MIGRATION_GUIDE.md` | Detailed AWS migration guide |
| `MIGRATION_CHECKLIST.md` | Visual checklist for manual deployment |
| `README.md` | Project overview |

---

## Detailed Deployment Process

### Pre-Deployment Checklist

- [ ] AWS Account created
- [ ] RDS MariaDB database created
- [ ] Lightsail instance launched (Ubuntu 22.04)
- [ ] Lightsail static IP assigned
- [ ] SSH key downloaded
- [ ] Moodle files ready (moodlehtml directory)
- [ ] Domain name purchased (optional but recommended)
- [ ] `.env` file created with correct values

### AWS RDS Setup

1. **Create RDS Database**
   ```
   - Engine: MariaDB 10.11
   - DB Instance Identifier: moodle-db
   - Master Username: moodle
   - Master Password: [STRONG PASSWORD]
   - Publicly Accessible: NO
   - Backup Retention: 7 days
   - Multi-AZ: Optional (for production)
   ```

2. **Note RDS Endpoint**
   - From AWS RDS Console → Databases → moodle-db → Connectivity
   - Copy the "Writer endpoint" (e.g., `moodle-db.c9akciq32.us-east-1.rds.amazonaws.com`)

3. **Security Group Configuration**
   - Add inbound rule: MySQL/Aurora (3306) from Lightsail security group

### Lightsail Setup

1. **Create Instance**
   ```
   - Location: Same region as RDS
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 22.04 LTS
   - Plan: $3.50/month (512 MB) minimum
   ```

2. **Configure Networking**
   - Create Static IP and attach to instance
   - Note the public IP address

3. **Configure Firewall**
   - SSH (22): Restrict to your IP
   - HTTP (80): 0.0.0.0/0
   - HTTPS (443): 0.0.0.0/0

### Configuration (.env File)

**Required Variables:**
```env
# AWS RDS
RDS_ENDPOINT=moodle-db.c9akciq32.us-east-1.rds.amazonaws.com
DB_NAME=moodle
DB_USER=moodle
DB_PASSWORD=YourStrongPassword123!

# Moodle
MOODLE_URL=https://moodle.yourdomain.com
SITE_NAME=My Moodle Site
ADMIN_EMAIL=admin@yourdomain.com

# AWS Region
AWS_REGION=us-east-1
```

**Optional Variables:**
```env
# SSL/HTTPS
LETSENCRYPT_DOMAIN=moodle.yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Backups
AWS_BACKUP_BUCKET=moodle-backups-bucket
BACKUP_FREQUENCY=daily

# Performance
PHP_MAX_MEMORY=256M
UPLOAD_MAX_FILESIZE=100M
```

### Deployment Steps

**1. SSH into Lightsail**
```bash
ssh -i lightsail-key.pem ubuntu@LIGHTSAIL_IP
```

**2. Upload Project Files**
```bash
# Already done via scp from local machine
# Verify files are present
ls -la ~/moodle-local/
```

**3. Verify Configuration**
```bash
cd ~/moodle-local
chmod +x verify-aws-config.sh
./verify-aws-config.sh
```

**4. Deploy Application**
```bash
chmod +x deploy-aws-v2.sh
./deploy-aws-v2.sh
```

This script will:
- Install Docker and Docker Compose
- Extract Moodle files
- Configure permissions
- Test RDS connection
- Start Docker containers
- Restore database (if backup available)

**5. Access Moodle**
- Open browser to: `http://LIGHTSAIL_IP` (or your domain if DNS configured)
- Complete Moodle installation wizard

**6. Setup SSL/HTTPS**
```bash
chmod +x setup-ssl.sh
./setup-ssl.sh yourdomain.com
```

**7. Configure DNS** (if using custom domain)
1. Go to your domain registrar
2. Create/Update A record pointing to Lightsail static IP
3. Wait for DNS propagation (5-15 minutes)
4. Test HTTPS connection

---

## Backup Strategy

### Automatic Backups

**RDS Automatic Backups:**
- Already configured (7-day retention)
- Managed by AWS
- Can restore to point-in-time

**Docker Volume Backups:**
Add to crontab on Lightsail:
```bash
# Run daily at 2 AM
0 2 * * * /home/ubuntu/backup-rds.sh >> ~/backup.log 2>&1

# Optional: Upload to S3
0 2 * * * /home/ubuntu/backup-rds.sh --to-s3 >> ~/backup.log 2>&1
```

### Manual Backups

```bash
# Database backup
./backup-rds.sh

# Upload to S3
./backup-rds.sh --to-s3

# Moodle files backup (optional)
tar -czf moodle_files_$(date +%Y%m%d).tar.gz moodlehtml/
```

---

## Monitoring & Maintenance

### Regular Checks

```bash
# Container status
docker compose ps

# Resource usage
docker stats

# View logs
docker compose logs -f moodle

# Check disk space
df -h

# Check memory
free -h
```

### Monthly Tasks

- [ ] Review CloudWatch logs
- [ ] Check RDS backup status
- [ ] Update Moodle (if updates available)
- [ ] Review security groups
- [ ] Test backup restoration

### Troubleshooting

**Cannot connect to RDS:**
```bash
# Test connectivity
docker compose exec moodle mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASSWORD -e "SELECT 1"

# Check security groups
# - RDS allows port 3306 from Lightsail
# - Lightsail and RDS in same region
# - RDS not restricted to private network
```

**Moodle returns 403 Forbidden:**
```bash
# Check file permissions
sudo chown -R 33:33 moodlehtml/
sudo chmod -R 755 moodlehtml/
docker compose restart moodle
```

**Database backup fails:**
```bash
# Verify credentials in .env
echo $RDS_ENDPOINT $DB_USER $DB_PASSWORD

# Test connection manually
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASSWORD -e "SHOW DATABASES;"
```

**SSL certificate not working:**
```bash
# Check certificate status
sudo certbot certificates

# View renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Manual renewal
sudo certbot renew --force-renewal
```

---

## Cost Estimation

| Service | Free Tier | After 12mo |
|---------|-----------|-----------|
| Lightsail | $3.50/mo | $3.50/mo |
| RDS MariaDB | Free | $15-25/mo |
| Data Transfer | $0-5/mo | $0-5/mo |
| Domain | $1-2/yr | $1-2/yr |
| **Total** | **$4-10/mo** | **$20-35/mo** |

---

## Security Best Practices

1. **Passwords**
   - Use strong, unique passwords (12+ chars, mixed case, numbers, symbols)
   - Store in secure location
   - Rotate every 90 days

2. **Network**
   - Restrict Lightsail SSH to your IP
   - Restrict RDS access to Lightsail only
   - Enable VPC security groups

3. **Backups**
   - Automated RDS backups (7-day retention)
   - Regular manual backups
   - Test restoration monthly

4. **SSL/HTTPS**
   - Always use HTTPS in production
   - Auto-renew Let's Encrypt certificates
   - Monitor certificate expiration

5. **Updates**
   - Keep Docker images updated
   - Apply Moodle security updates
   - Review AWS security bulletins

---

## Scaling for Growth

### Upgrade Lightsail Instance
```bash
# Stop Moodle
docker compose down

# Upgrade instance in AWS console (1-2 hours)

# Restart Moodle
docker compose up -d
```

### Upgrade RDS Instance
```bash
# Moodle remains online during minor version upgrades
# Major upgrades may require brief downtime

# AWS handles upgrade in console
```

### Add CloudFront CDN
```bash
# Optional: Speeds up static content delivery
# Configure in AWS CloudFront console
```

---

## Disaster Recovery

### Restore from RDS Backup

1. Create new RDS instance from snapshot
2. Update .env with new endpoint
3. Restart Docker containers
4. Test application

### Full Disaster Recovery

```bash
# 1. Create new Lightsail instance
# 2. Deploy fresh installation
# 3. Restore RDS from backup
# 4. Update DNS to new IP
```

---

## Next Steps

1. ✅ Create AWS Account and resources
2. ✅ Edit .env with AWS details
3. ✅ Run verify-aws-config.sh
4. ✅ Run deploy-aws-v2.sh
5. ✅ Complete Moodle installation
6. ✅ Setup SSL certificate
7. ✅ Configure backups
8. ✅ Test everything
9. ✅ Schedule maintenance tasks
10. ✅ Monitor and maintain

---

## Support & Resources

- **AWS Lightsail**: https://docs.aws.amazon.com/lightsail/
- **AWS RDS**: https://docs.aws.amazon.com/rds/
- **Moodle Docs**: https://docs.moodle.org/
- **Docker**: https://docs.docker.com/
- **Let's Encrypt**: https://letsencrypt.org/

---

## Questions?

Refer to:
1. `MIGRATION_CHECKLIST.md` - Quick visual guide
2. `AWS_MIGRATION_GUIDE.md` - Detailed technical guide
3. `docker compose logs moodle` - Application logs
4. AWS Console → CloudWatch - Infrastructure logs
