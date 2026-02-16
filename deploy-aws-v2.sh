#!/bin/bash
#
# AWS Lightsail Moodle Deployment Script v2
# Automated deployment and configuration for AWS
#
# Prerequisites:
# 1. AWS Lightsail instance running Ubuntu 22.04
# 2. RDS MariaDB database created and available
# 3. Migration files uploaded (moodle-migration.tar.gz or moodlehtml/)
# 4. .env file with AWS configuration
#
# Usage: ./deploy-to-aws.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.aws.yml"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  AWS Lightsail Moodle Deployment${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# ============================================
# Step 1: Verify Prerequisites
# ============================================
echo -e "${YELLOW}[1/8] Checking Prerequisites...${NC}"

# Check if running on Ubuntu
if ! grep -qi ubuntu /etc/os-release; then
    echo -e "${RED}✗ This script requires Ubuntu${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Ubuntu detected${NC}"

# Check for required tools
for cmd in curl wget git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}✗ $cmd is required but not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required tools found${NC}"

# Check for .env file
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}✗ .env file not found at $ENV_FILE${NC}"
    echo "Create .env file from .env.aws.example:"
    echo "  cp .env.aws.example .env"
    exit 1
fi
echo -e "${GREEN}✓ .env file found${NC}"

# Source the .env file
source "$ENV_FILE"

# Validate required variables
REQUIRED_VARS=("RDS_ENDPOINT" "DB_NAME" "DB_USER" "DB_PASSWORD" "MOODLE_URL")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}✗ Missing required variable: $var${NC}"
        echo "Please update your .env file"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required variables set${NC}"
echo ""

# ============================================
# Step 2: System Updates
# ============================================
echo -e "${YELLOW}[2/8] Updating System Packages...${NC}"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    git \
    unzip \
    zip \
    mariadb-client \
    htop \
    nano
echo -e "${GREEN}✓ System packages updated${NC}"
echo ""

# ============================================
# Step 3: Docker Installation
# ============================================
echo -e "${YELLOW}[3/8] Setting Up Docker...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker already installed${NC}"
else
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh -qq > /dev/null 2>&1
    rm get-docker.sh
    
    # Add current user to docker group
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✓ Docker installed${NC}"
fi

# Verify Docker
if docker --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker version: $(docker --version)${NC}"
else
    echo -e "${RED}✗ Docker installation failed${NC}"
    exit 1
fi

# Install Docker Compose
if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose already installed${NC}"
else
    echo "Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
fi
echo ""

# ============================================
# Step 4: Extract Moodle Files
# ============================================
echo -e "${YELLOW}[4/8] Preparing Moodle Files...${NC}"

MOODLE_DIR="$SCRIPT_DIR/moodlehtml"

# Check if moodlehtml needs extraction
if [ ! -d "$MOODLE_DIR" ] || [ -z "$(ls -A $MOODLE_DIR 2>/dev/null)" ]; then
    if [ -f "$SCRIPT_DIR/moodle-migration.tar.gz" ]; then
        echo "Extracting Moodle files..."
        mkdir -p "$MOODLE_DIR"
        tar -xzf "$SCRIPT_DIR/moodle-migration.tar.gz" -C "$SCRIPT_DIR"
        rm "$SCRIPT_DIR/moodle-migration.tar.gz"
        echo -e "${GREEN}✓ Moodle files extracted${NC}"
    else
        echo -e "${RED}✗ Moodle files not found${NC}"
        echo "Place moodlehtml/ directory or moodle-migration.tar.gz in this directory"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Moodle files already present${NC}"
fi

# Fix permissions
echo "Setting file permissions..."
sudo chown -R 33:33 "$MOODLE_DIR"
sudo chmod -R 755 "$MOODLE_DIR"
echo -e "${GREEN}✓ Permissions configured${NC}"
echo ""

# ============================================
# Step 5: Database Connection Test
# ============================================
echo -e "${YELLOW}[5/8] Testing Database Connection...${NC}"

echo "Attempting to connect to RDS: $RDS_ENDPOINT"
if mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Failed to connect to database${NC}"
    echo "Please verify:"
    echo "  - RDS endpoint is correct: $RDS_ENDPOINT"
    echo "  - Database credentials are correct"
    echo "  - RDS security group allows your Lightsail instance"
    echo "  - RDS is in the same region as Lightsail"
    exit 1
fi
echo ""

# ============================================
# Step 6: Docker Compose Configuration
# ============================================
echo -e "${YELLOW}[6/8] Configuring Docker Compose...${NC}"

# Check if docker-compose.aws.yml exists
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo -e "${RED}✗ docker-compose.aws.yml not found${NC}"
    exit 1
fi

# Copy to docker-compose.yml for use
cp "$DOCKER_COMPOSE_FILE" "$SCRIPT_DIR/docker-compose.yml"

echo -e "${GREEN}✓ Docker Compose configured${NC}"
echo ""

# ============================================
# Step 7: Start Docker Containers
# ============================================
echo -e "${YELLOW}[7/8] Starting Docker Containers...${NC}"

cd "$SCRIPT_DIR"

# Stop any existing containers
docker compose down 2>/dev/null || true

# Start containers with environment file
echo "Starting Moodle container..."
docker compose --env-file "$ENV_FILE" up -d

# Wait for container to be ready
echo "Waiting for Moodle to be ready..."
ATTEMPT=0
MAX_ATTEMPTS=30

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker compose exec moodle curl -s http://localhost/index.php > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Moodle container is ready${NC}"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo -n "."
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo ""
    echo -e "${YELLOW}⚠ Timeout waiting for Moodle${NC}"
    echo "Container may still be starting - check logs:"
    echo "  docker compose logs moodle"
fi

echo ""

# ============================================
# Step 8: Database Restoration (Optional)
# ============================================
echo -e "${YELLOW}[8/8] Database Setup...${NC}"

if [ -f "$SCRIPT_DIR/migration-backup/moodle_backup.sql" ]; then
    read -p "Restore database from backup? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Restoring database..."
        mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$SCRIPT_DIR/migration-backup/moodle_backup.sql"
        echo -e "${GREEN}✓ Database restored${NC}"
    fi
else
    echo "No backup file found - fresh database setup"
fi
echo ""

# ============================================
# Post-Installation Summary
# ============================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Access Your Moodle:${NC}"
echo -e "  URL: ${MOODLE_URL}"
echo ""

echo -e "${YELLOW}Important Information:${NC}"
echo "  - Database: $DB_NAME on $RDS_ENDPOINT"
echo "  - Moodle Files: $MOODLE_DIR"
echo "  - Data Directory: $(docker volume inspect moodle-local_moodledata 2>/dev/null | grep Mountpoint || echo 'Docker managed volume')"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View container status:"
echo "    docker compose ps"
echo ""
echo "  View Moodle logs:"
echo "    docker compose logs -f moodle"
echo ""
echo "  Access container shell:"
echo "    docker compose exec moodle bash"
echo ""
echo "  Restart Moodle:"
echo "    docker compose restart moodle"
echo ""
echo "  Stop all containers:"
echo "    docker compose down"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Open $MOODLE_URL in your browser"
echo "2. Complete the Moodle installation wizard"
echo "3. Set up SSL certificate (Let's Encrypt)"
echo "4. Configure backups"
echo "5. Add administrator users"
echo ""

echo -e "${YELLOW}Monitoring:${NC}"
echo "  docker stats              # View resource usage"
echo "  free -h                   # Check memory"
echo "  df -h                     # Check disk space"
echo ""

echo -e "${YELLOW}Documentation:${NC}"
echo "  - AWS Migration Guide: AWS_MIGRATION_GUIDE.md"
echo "  - Troubleshooting: Check docker compose logs"
echo "  - Moodle Docs: https://docs.moodle.org"
echo ""

# Create a status file
echo "$(date)" > "$SCRIPT_DIR/.deployment_status"
echo -e "${GREEN}Deployment status saved${NC}"
echo ""
