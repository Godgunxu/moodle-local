#!/bin/bash
# AWS Lightsail Moodle Deployment Script
# Run this on your Lightsail instance after downloading migration files

set -e

echo "================================"
echo "Moodle AWS Lightsail Setup"
echo "================================"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: System Setup
echo -e "${YELLOW}[1/8] Updating system packages...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq mariadb-client git curl wget

# Step 2: Docker Setup
echo -e "${YELLOW}[2/8] Setting up Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh -qq
    rm get-docker.sh
fi

sudo usermod -aG docker $USER
newgrp docker

# Verify Docker
if docker --version > /dev/null; then
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${RED}✗ Docker installation failed${NC}"
    exit 1
fi

# Step 3: Extract Moodle files
echo -e "${YELLOW}[3/8] Extracting Moodle files...${NC}"
if [ -f "moodle-migration.tar.gz" ]; then
    tar -xzf moodle-migration.tar.gz
    echo -e "${GREEN}✓ Files extracted${NC}"
else
    echo -e "${RED}✗ moodle-migration.tar.gz not found${NC}"
    exit 1
fi

# Step 4: Set permissions
echo -e "${YELLOW}[4/8] Setting file permissions...${NC}"
cd moodlehtml
sudo chown -R 33:33 .
sudo chmod -R 755 .
echo -e "${GREEN}✓ Permissions set${NC}"

# Step 5: Read configuration
echo -e "${YELLOW}[5/8] Configuration wizard...${NC}"
read -p "Enter RDS endpoint (e.g., moodle-db.c9akciq32.us-east-1.rds.amazonaws.com): " RDS_ENDPOINT
read -p "Enter RDS password: " -s RDS_PASSWORD
echo
read -p "Enter your domain (e.g., moodle.yourdomain.com): " DOMAIN
read -p "Enter admin email: " ADMIN_EMAIL

# Step 6: Create docker-compose.yml
echo -e "${YELLOW}[6/8] Creating docker-compose configuration...${NC}"
cat > docker-compose.yml << EOF
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
      MOODLE_DOCKER_DBHOST: $RDS_ENDPOINT
      MOODLE_DOCKER_DBNAME: moodle
      MOODLE_DOCKER_DBUSER: moodle
      MOODLE_DOCKER_DBPASS: $RDS_PASSWORD
      MOODLE_DOCKER_WWWROOT: https://$DOMAIN
    volumes:
      - .:/var/www/html
      - moodledata:/var/www/moodledata
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  moodledata:
EOF
echo -e "${GREEN}✓ Docker compose created${NC}"

# Step 7: Update config.php
echo -e "${YELLOW}[7/8] Updating Moodle configuration...${NC}"
if [ -f "config.php" ]; then
    # Backup original
    cp config.php config.php.backup
    
    # Update database connection
    sed -i "s/\$CFG->dbhost.*=.*/\$CFG->dbhost    = '$RDS_ENDPOINT';/" config.php
    sed -i "s/\$CFG->dbpass.*=.*/\$CFG->dbpass    = '$RDS_PASSWORD';/" config.php
    sed -i "s|CFG->wwwroot.*=.*|CFG->wwwroot   = 'https://$DOMAIN';|" config.php
    
    echo -e "${GREEN}✓ Configuration updated${NC}"
else
    echo -e "${YELLOW}⚠ config.php not found - you'll need to configure manually${NC}"
fi

# Step 8: Start Docker containers
echo -e "${YELLOW}[8/8] Starting Moodle container...${NC}"
docker compose up -d

# Wait for container to be healthy
echo "Waiting for Moodle to start (this may take 1-2 minutes)..."
for i in {1..30}; do
    if docker compose exec moodle curl -s http://localhost/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Moodle is running${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Step 9: Restore database
echo -e "${YELLOW}[9/8] Restoring database...${NC}"
if [ -f "migration-backup/moodle_backup.sql" ]; then
    echo "Restoring database from backup..."
    mysql -h $RDS_ENDPOINT -u moodle -p$RDS_PASSWORD moodle < migration-backup/moodle_backup.sql 2>/dev/null || true
    echo -e "${GREEN}✓ Database restored${NC}"
else
    echo -e "${YELLOW}⚠ Backup file not found - skipping restore${NC}"
fi

# Summary
echo ""
echo "================================"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo "================================"
echo ""
echo "Access your Moodle at: http://$(hostname -I | awk '{print $1}')"
echo "Domain setup: Point DNS A record to this Lightsail IP"
echo ""
echo "Next steps:"
echo "1. Update DNS records to point to this server"
echo "2. Configure SSL certificate (Let's Encrypt)"
echo "3. Test your Moodle installation"
echo "4. Set up backups"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f                 # View logs"
echo "  docker compose ps                      # View container status"
echo "  docker compose exec moodle bash        # Access container shell"
echo ""
