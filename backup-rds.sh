#!/bin/bash
#
# AWS RDS Backup Script for Moodle
# Backs up RDS database to local storage and optionally to S3
#
# Prerequisites:
# - Access to RDS database
# - AWS CLI configured (for S3 upload)
#
# Usage: ./backup-rds.sh [--to-s3]
#

set -e

# Configuration
BACKUP_DIR="./backups/rds"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/moodle_db_$TIMESTAMP.sql"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting RDS Backup...${NC}"

# Load environment
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi
source .env

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
echo "Backing up database: $DB_NAME"
echo "RDS Endpoint: $RDS_ENDPOINT"

if mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection verified${NC}"
else
    echo -e "${RED}❌ Failed to connect to RDS database${NC}"
    exit 1
fi

echo "Creating backup..."
mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$BACKUP_FILE"

# Compress backup
echo "Compressing backup..."
gzip "$BACKUP_FILE"
BACKUP_FILE="$BACKUP_FILE.gz"

# Get file size
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE ($SIZE)${NC}"

# Optional: Upload to S3
if [ "$1" == "--to-s3" ]; then
    if [ -z "$AWS_BACKUP_BUCKET" ]; then
        echo -e "${YELLOW}⚠ AWS_BACKUP_BUCKET not set in .env${NC}"
    else
        echo "Uploading to S3..."
        if aws s3 cp "$BACKUP_FILE" "s3://$AWS_BACKUP_BUCKET/backups/$(basename $BACKUP_FILE)"; then
            echo -e "${GREEN}✓ Backup uploaded to S3${NC}"
        else
            echo -e "${RED}❌ Failed to upload to S3${NC}"
        fi
    fi
fi

# Keep only last 30 days of backups
echo "Cleaning old backups..."
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo -e "${GREEN}✅ Backup complete${NC}"
echo ""
echo "Location: $BACKUP_FILE"
echo "Next manual backup: $(date -d '+1 day' '+%Y-%m-%d')"
