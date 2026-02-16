# Moodle Docker to AWS Migration

Complete guide and automation scripts for migrating a local Docker-based Moodle installation to AWS using Lightsail and RDS.

## 📋 Overview

This project provides:
- **Docker Compose** setup for local Moodle development
- **AWS Migration Scripts** for automated deployment to Lightsail
- **SSL/HTTPS** configuration with Let's Encrypt
- **Database Backup & Restore** tools
- **Comprehensive Documentation** with step-by-step guides

## 🚀 Quick Start

### Local Setup
```bash
# Start Moodle locally
docker compose up -d

# Access at http://localhost:8080
```

### AWS Migration
```bash
# 1. Review the migration checklist
cat MIGRATION_CHECKLIST.md

# 2. Follow the detailed guide
cat AWS_MIGRATION_GUIDE.md

# 3. On Lightsail instance, run:
./deploy-to-aws.sh

# 4. Setup SSL
./setup-ssl.sh yourdomain.com
```

## 📁 Project Structure

```
moodle-local/
├── 📚 DOCUMENTATION
├── README.md                          # This file
├── AWS_QUICK_REFERENCE.md             # ⭐ File index and quick guide
├── AWS_INFRASTRUCTURE.md              # AWS setup guide (RDS, Lightsail, DNS)
├── AWS_DEPLOYMENT.md                  # Deployment process and troubleshooting
├── AWS_MIGRATION_GUIDE.md             # Detailed technical migration guide
├── MIGRATION_CHECKLIST.md             # Visual step-by-step checklist
│
├── 🧩 CONFIGURATION FILES
├── docker-compose.yml                 # Local development (uses .env)
├── docker-compose.dev.yml             # Development reference config
├── docker-compose.aws.yml             # AWS production config
├── .env.example                       # Local template
├── .env.aws.example                   # AWS template
│
├── 🚀 DEPLOYMENT SCRIPTS
├── deploy-aws-v2.sh                   # ⭐ Main AWS deployment script (NEW!)
├── verify-aws-config.sh               # Config validation before deploy (NEW!)
├── backup-rds.sh                      # RDS database backup script (NEW!)
├── setup-ssl.sh                       # SSL/HTTPS certificate setup
├── deploy-to-aws.sh                   # Legacy deployment script
├── push-to-github.sh                  # Push to GitHub
│
├── 🐳 APPLICATION FILES
├── moodlehtml/                        # Moodle 4.4 LTS source (not in git, ~464MB)
├── migration-backup/                  # Database backups (not in git)
└── backups/                           # Local backup directory
```

## 🧩 Components

### Local Setup
- **Docker Compose** with MariaDB and Moodle containers
- **PHP 8.1** with Apache
- **MariaDB 10.11** matching AWS RDS

### AWS Architecture
```
┌─────────────────────────────────┐
│  AWS Account                    │
├─────────────────────────────────┤
│ Lightsail Instance (Ubuntu 22)  │
│  ├─ Docker Compose              │
│  ├─ Moodle PHP-Apache           │
│  └─ moodledata volume           │
│                                 │
│ RDS MariaDB (Managed)           │
│  ├─ moodle database             │
│  ├─ Automatic backups           │
│  └─ Multi-AZ failover (opt.)    │
│                                 │
│ Route 53 (Optional)             │
│  └─ DNS management              │
└─────────────────────────────────┘
```

## 📚 Documentation Guide

### Getting Started
1. **[AWS_QUICK_REFERENCE.md](AWS_QUICK_REFERENCE.md)** ⭐ **START HERE** - Quick overview of all files
2. **[AWS_INFRASTRUCTURE.md](AWS_INFRASTRUCTURE.md)** - Step-by-step AWS setup (RDS, Lightsail)
3. **[AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md)** - Deployment process and configuration
4. **[AWS_MIGRATION_GUIDE.md](AWS_MIGRATION_GUIDE.md)** - Detailed technical reference
5. **[MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)** - Visual checklist for manual deployment

### During Deployment
- **[deploy-to-aws.sh](deploy-to-aws.sh)** - Interactive deployment script
  - Auto-detects and configures environment
  - Asks for RDS credentials and domain
  - Handles database restoration
  
- **[setup-ssl.sh](setup-ssl.sh)** - SSL setup script
  - Installs Let's Encrypt Certbot
  - Generates free SSL certificate
  - Configures auto-renewal

## ⚡ Quick Commands

```bash
# Local Development
docker compose up -d              # Start containers
docker compose down               # Stop containers
docker compose logs -f            # View logs
docker compose exec moodle bash   # Access container

# Database Operations
docker exec moodle-db mariadb-dump -uroot -prootpass moodle > backup.sql
docker exec moodle-db mysql -uroot -prootpass < restore.sql

# Prepare for Migration
mkdir migration-backup
docker exec moodle-db mariadb-dump -uroot -prootpass moodle > migration-backup/moodle_backup.sql
tar -czf moodle-migration.tar.gz moodlehtml/ migration-backup/

# On AWS Lightsail
docker compose ps                 # Check container status
docker compose logs moodle        # View Moodle logs
docker stats                      # Monitor resource usage
```

## 🔧 Configuration

### Local Environment Variables
Edit `docker-compose.yml`:
```yaml
environment:
  MOODLE_DOCKER_DBTYPE: mariadb
  MOODLE_DOCKER_DBHOST: db
  MOODLE_DOCKER_DBUSER: moodle
  MOODLE_DOCKER_DBPASS: moodlepass
```

### AWS Environment Variables
On Lightsail, supplied by `deploy-to-aws.sh`:
```bash
MOODLE_DOCKER_DBHOST: <RDS_ENDPOINT>
MOODLE_DOCKER_DBPASS: <YOUR_STRONG_PASSWORD>
MOODLE_DOCKER_WWWROOT: https://yourdomain.com
```

## 💰 Cost Estimation

| Service | Cost/Month | Notes |
|---------|-----------|-------|
| Lightsail (512 MB) | $3.50 | Includes 1 TB data transfer |
| RDS MariaDB | Free* | Free tier first 12 months |
| Domain | $1-2 | If using Route 53 |
| Extra Data Transfer | $0-5 | Typically minimal |
| **Total** | **$4-10** | First year; $18-30 after |

*After free tier: ~$15-25/month for `db.t3.micro`

## 🔒 Security Considerations

1. **Passwords**: Use strong, unique passwords for production
2. **Security Groups**: Restrict database access to Lightsail only
3. **SSL/HTTPS**: Always use HTTPS in production
4. **Backups**: Regular automated backups configured
5. **Firewall**: Lightsail firewall restricts SSH access by IP

## 🆘 Troubleshooting

### 403 Forbidden
```bash
docker compose exec moodle chown -R www-data:www-data /var/www/html
docker compose restart moodle
```

### Database Connection Error
```bash
# Test from container
docker compose exec moodle mysql -h <RDS_ENDPOINT> -u moodle -p<PASSWORD> -e "SELECT 1"

# Verify security group allows port 3306
# Confirm RDS and Lightsail in same region
```

### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Manual renewal
sudo certbot renew --force-renewal

# View renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

See [AWS_MIGRATION_GUIDE.md](AWS_MIGRATION_GUIDE.md#-troubleshooting) for more solutions.

## 📦 Moodle Version

- **Moodle**: 4.4 LTS (Long-Term Support)
- **PHP**: 8.1
- **Database**: MariaDB 10.11
- **OS**: Ubuntu 22.04 LTS

## 🔄 Maintenance

### Regular Tasks
- **Daily**: Automated RDS backups
- **Weekly**: Review server logs (`docker compose logs`)
- **Monthly**: Check for Moodle updates
- **Quarterly**: Test disaster recovery (restore from backup)

### Updating Moodle
```bash
# Pull latest PHP image on Lightsail
docker compose pull
docker compose down
docker compose up -d
```

## 📝 Related Files

- `moodlehtml/` - Moodle 4.4 LTS source code (not in git, download separately)
- `migration-backup/moodle_backup.sql` - Database backup (created during setup)
- `.docker-compose.override.yml` - Optional local overrides

## 🎯 Next Steps

1. **Review** the [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)
2. **Create AWS Account** if you don't have one
3. **Follow** the [AWS_MIGRATION_GUIDE.md](AWS_MIGRATION_GUIDE.md)
4. **Run** deployment scripts on Lightsail
5. **Configure** DNS and SSL
6. **Test** your Moodle installation
7. **Monitor** and maintain

## 📞 Support & Resources

### Documentation
- [Moodle Documentation](https://docs.moodle.org/)
- [AWS Lightsail Docs](https://docs.aws.amazon.com/lightsail/)
- [AWS RDS Docs](https://docs.aws.amazon.com/rds/)

### Tools & Links
- [Docker Documentation](https://docs.docker.com/)
- [Certbot (Let's Encrypt)](https://certbot.eff.org/)
- [MariaDB Documentation](https://mariadb.com/documentation/)

## 📜 License

This migration toolkit is provided as-is. Moodle is licensed under GPL v3.

## 👤 Author

Created for seamless migration of Docker-based Moodle installations to AWS.

## 🐛 Issues & Contributions

If you encounter issues or have improvements:
1. Check the troubleshooting section in [AWS_MIGRATION_GUIDE.md](AWS_MIGRATION_GUIDE.md)
2. Review logs: `docker compose logs`
3. Test database connectivity manually

---

**Start here**: Read [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) for your first steps!
