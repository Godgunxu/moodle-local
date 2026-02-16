# Moodle Migration to AWS - Complete Guide

## Overview
Migrate your local Docker Moodle setup to AWS using:
- **Lightsail**: Virtual server with pre-installed Docker
- **RDS**: Managed MariaDB database
- **S3**: File storage and backups
- **Route 53**: DNS management (optional, if using custom domain)

---

## Prerequisites

1. **AWS Account** - Create at https://aws.amazon.com
2. **AWS CLI** - Install on your local machine
3. **Domain** - Have your domain ready
4. **Backups** - Database and files backed up locally ✓ (Already done)

---

## PHASE 1: AWS Infrastructure Setup

### Step 1.1: Create RDS MariaDB Database

1. **Go to AWS Console** → RDS → Databases → Create Database
2. **Configuration**:
   - Engine: MariaDB
   - Version: 10.11 (matching your local setup)
   - Template: Free tier (if eligible)
   - DB Instance Identifier: `moodle-db`
   - Master Username: `moodle`
   - Master Password: *Use strong password (NOT `moodlepass`)*
   - DB Instance Class: `db.t3.micro` (Free tier)
   - Storage: 20 GB
   - No public accessibility (yet) - set to NO initially

3. **Security Group**:
   - Create new security group: `moodle-rds-sg`
   - Allow inbound: MariaDB (3306) from your Lightsail instance's security group

4. **Database Options**:
   - Initial database name: `moodle`
   - Enable backups: Yes (7 days retention)
   - Copy tags to snapshots: Yes
   - Enable deletion protection: Yes

5. **Create** and wait for database to be available (5-10 minutes)

### Step 1.2: Create Lightsail Instance

1. **Go to AWS Console** → Lightsail → Create Instance
2. **Configuration**:
   - Location: Same region as RDS
   - Platform: Linux/Unix
   - Blueprint: OS Only → Ubuntu 22.04 LTS
   - Instance Plan: $5-10/month (starts with 1 GB RAM, 1 vCPU)

3. **Network**:
   - Create static IP (required for fixed DNS)
   - Enable public access

4. **Add Launch Script** (optional - for automated setup):
   ```bash
   #!/bin/bash
   apt-get update
   apt-get install -y docker.io docker-compose git
   usermod -aG docker ubuntu
   ```

5. **Create Instance** and wait for startup (2-3 minutes)

### Step 1.3: Configure Security Groups

1. **RDS Security Group** (moodle-rds-sg):
   - Inbound: MySQL/Aurora on 3306 from Lightsail's security group
   
2. **Lightsail Security Group**:
   - Inbound: SSH (22) from your IP
   - Inbound: HTTP (80) from 0.0.0.0/0
   - Inbound: HTTPS (443) from 0.0.0.0/0

---

## PHASE 2: Prepare Migration Files

### Step 2.1: Create Migration Package

On your **local machine**:

```bash
cd /home/jason/Downloads/moodle-local
tar -czf moodle-migration.tar.gz \
  moodlehtml/ \
  migration-backup/moodle_backup.sql

ls -lh moodle-migration.tar.gz
```

### Step 2.2: Create New docker-compose.yml for AWS

Create a new file: `docker-compose-aws.yml`

```yaml
version: '3.8'

services:
  moodle:
    image: moodlehq/moodle-php-apache:8.1
    container_name: moodle-app
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      MOODLE_DOCKER_DBTYPE: mariadb
      MOODLE_DOCKER_DBHOST: <RDS_ENDPOINT>  # e.g., moodle-db.c9akciq32.us-east-1.rds.amazonaws.com
      MOODLE_DOCKER_DBNAME: moodle
      MOODLE_DOCKER_DBUSER: moodle
      MOODLE_DOCKER_DBPASS: <YOUR_STRONG_PASSWORD>
      MOODLE_DOCKER_WWWROOT: https://yourdomain.com  # Your domain
    volumes:
      - ./moodlehtml:/var/www/html
      - moodledata:/var/www/moodledata
    depends_on:
      - db-migration

  db-migration:
    # Temporary local MariaDB just for migration
    image: mariadb:10.11
    container_name: moodle-migration-db
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: rootpass
      MARIADB_DATABASE: moodle
      MARIADB_USER: moodle
      MARIADB_PASSWORD: <YOUR_STRONG_PASSWORD>
    volumes:
      - ./migration-backup/moodle_backup.sql:/docker-entrypoint-initdb.d/restore.sql
      - migration_data:/var/lib/mysql

volumes:
  moodledata:
  migration_data:
```

---

## PHASE 3: Deploy to Lightsail

### Step 3.1: Connect to Lightsail Instance

1. **Get SSH Connection String**:
   - Lightsail Console → Your Instance → Connect Using SSH (blue button)
   - Or use SSH key if downloaded

2. **Set up instance**:
   ```bash
   sudo apt-get update
   sudo apt-get upgrade -y
   sudo apt-get install -y docker.io docker-compose git
   sudo usermod -aG docker ubuntu
   newgrp docker
   ```

### Step 3.2: Upload Migration Files

From **your local machine**:

```bash
# Copy files to Lightsail (replace IP with your Lightsail static IP)
scp -i /path/to/key.pem moodle-migration.tar.gz ubuntu@<LIGHTSAIL_IP>:~/

# Or use Lightsail file transfer (in console)
```

### Step 3.3: Extract and Set Up on Lightsail

SSH into Lightsail and run:

```bash
cd ~
tar -xzf moodle-migration.tar.gz
cd moodlehtml

# Fix permissions
sudo chown -R 33:33 .
sudo chmod -R 755 .
```

---

## PHASE 4: Database Migration

### Step 4.1: Restore Database to RDS

On **Lightsail instance**:

```bash
# Install MariaDB client
sudo apt-get install -y mariadb-client

# Get RDS endpoint from AWS Console (RDS → Databases → moodle-db → Endpoint)

# Restore database
mysql -h <RDS_ENDPOINT> -u moodle -p < migration-backup/moodle_backup.sql

# Verify
mysql -h <RDS_ENDPOINT> -u moodle -p
mysql> show databases;
mysql> use moodle;
mysql> select count(*) from mdl_user;
mysql> exit;
```

### Step 4.2: Update Moodle Config

Edit `/home/ubuntu/moodlehtml/config.php`:

```php
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native/mariadb';
$CFG->dbhost    = '<RDS_ENDPOINT>';  // AWS RDS endpoint
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodle';
$CFG->dbpass    = '<YOUR_STRONG_PASSWORD>';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
    'dbpersist' => 0,
    'dbsocket'  => '',
    'dbport'    => '',
);

$CFG->wwwroot   = 'https://yourdomain.com';  // Your domain
$CFG->dataroot  = '/var/www/moodledata';
```

---

## PHASE 5: Launch Moodle on Lightsail

### Step 5.1: Create docker-compose.yml on Lightsail

```bash
cd ~/moodlehtml

# Create production docker-compose.yml (without local database)
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  moodle:
    image: moodlehq/moodle-php-apache:8.1
    container_name: moodle-app
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      MOODLE_DOCKER_DBTYPE: mariadb
      MOODLE_DOCKER_DBHOST: <RDS_ENDPOINT>
      MOODLE_DOCKER_DBNAME: moodle
      MOODLE_DOCKER_DBUSER: moodle
      MOODLE_DOCKER_DBPASS: <YOUR_PASSWORD>
    volumes:
      - .:/var/www/html
      - moodledata:/var/www/moodledata

volumes:
  moodledata:
EOF
```

### Step 5.2: Start Moodle

```bash
docker compose up -d
docker compose logs -f moodle

# Verify it's running
docker ps
```

---

## PHASE 6: DNS & SSL Setup

### Step 6.1: Update DNS Records

1. **Go to your domain registrar** (GoDaddy, Namecheap, etc.)
2. **Add/Update A Record**:
   - Name: `@` or your subdomain
   - Type: A
   - Value: Your Lightsail static IP
   - TTL: 3600

3. **Wait for DNS propagation** (up to 24 hours, usually faster)

### Step 6.2: Install SSL Certificate (Let's Encrypt)

On **Lightsail instance**:

```bash
sudo apt-get install -y certbot python3-certbot-apache

# Stop Moodle temporarily
docker compose down

# Get certificate
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Locations:
# Certificate: /etc/letsencrypt/live/yourdomain.com/fullchain.pem
# Key: /etc/letsencrypt/live/yourdomain.com/privkey.pem

# Update docker-compose.yml to mount certificates:
# volumes:
#   - /etc/letsencrypt:/etc/letsencrypt:ro
```

### Step 6.3: Update Apache Config in Container

```bash
# Create apache config that handles SSL
cat > /home/ubuntu/ssl-config.conf << 'EOF'
<VirtualHost *:443>
  ServerName yourdomain.com
  ServerAlias www.yourdomain.com
  
  DocumentRoot /var/www/html
  
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/yourdomain.com/privkey.pem
</VirtualHost>

<VirtualHost *:80>
  ServerName yourdomain.com
  ServerAlias www.yourdomain.com
  Redirect permanent / https://yourdomain.com/
</VirtualHost>
EOF

# Mount in docker-compose.yml
```

### Step 6.4: Restart Moodle

```bash
docker compose up -d
```

---

## PHASE 7: Verification & Testing

### Pre-Launch Checklist:

```bash
# 1. Check Moodle is running
curl http://localhost  # Should return HTML

# 2. Check database connection
docker compose exec moodle mysql -h <RDS_ENDPOINT> -u moodle -p moodle -e "SELECT COUNT(*) FROM mdl_user;"

# 3. Check file permissions
docker compose exec moodle ls -la /var/www/moodledata/

# 4. Verify config
docker compose exec moodle cat /var/www/html/config.php | grep dbhost
```

### Access Your Moodle:

1. Open `https://yourdomain.com` in browser
2. Log in with admin credentials
3. Test user login
4. Upload a test file
5. Check database connections work

---

## PHASE 8: Post-Migration

### Backup Setup

```bash
# Create weekly backup script
cat > /home/ubuntu/backup-moodle.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Database backup
mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> moodle | gzip > $BACKUP_DIR/moodle_db_$(date +%Y%m%d).sql.gz

# Files backup (optional, for S3)
tar -czf $BACKUP_DIR/moodle_files_$(date +%Y%m%d).tar.gz /home/ubuntu/moodlehtml

# Keep only last 30 days
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
EOF

chmod +x /home/ubuntu/backup-moodle.sh

# Add to crontab (run daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup-moodle.sh") | crontab -
```

### Monitor Performance

```bash
# Check Docker stats
docker stats

# Check disk space
df -h

# Check memory
free -h
```

---

## Cost Estimation

| Service | Size | Cost/Month |
|---------|------|-----------|
| Lightsail | 512MB RAM | $3.50 |
| RDS MariaDB | db.t3.micro | $0 (Free tier) or $15-25 |
| Data Transfer | Minimal | $0-5 |
| Domain | Per year | $10-15 |
| **Total** | | **$15-50/month** |

---

## Troubleshooting

### 403 Forbidden Error
```bash
# Fix file permissions
sudo chown -R 33:33 moodlehtml/
sudo chmod -R 755 moodlehtml/
docker compose restart moodle
```

### Database Connection Error
```bash
# Test connectivity
docker compose exec moodle mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> -e "SELECT 1"

# Check security groups allow port 3306 from Lightsail
# Check RDS is publicly accessible (or set up VPC peering)
```

### SSL Certificate Issues
```bash
# Renew certificate
sudo certbot renew --dry-run

# Auto-renewal setup
sudo systemctl enable certbot.timer
```

---

## Rollback Plan

If something goes wrong:

1. Keep local backups
2. RDS automatic backups (7 days retention)
3. Create Lightsail snapshot before making changes
4. Document all configurations

---

## Next Steps

1. ✅ **Create AWS account**
2. ✅ **Create RDS database** (5-10 min)
3. ✅ **Launch Lightsail instance** (2-3 min)
4. ✅ **Upload migration files**
5. ✅ **Restore database**
6. ✅ **Launch Docker containers**
7. ✅ **Configure DNS**
8. ✅ **Set up SSL**
9. ✅ **Test everything**
10. ✅ **Configure backups**

---

## Need Help?

- AWS Lightsail Documentation: https://docs.aws.amazon.com/lightsail/
- AWS RDS Documentation: https://docs.aws.amazon.com/rds/
- Moodle Docker: https://hub.docker.com/r/moodlehq/moodle-php-apache
- Moodle Admin: https://docs.moodle.org/en/Administration
