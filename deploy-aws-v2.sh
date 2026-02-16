#!/bin/bash
# AWS Lightsail Moodle Deployment - Single Script
# Move entire Moodle web to AWS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load configuration
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found"
    echo "Create it: cp .env.aws.example .env"
    exit 1
fi
source "$ENV_FILE"

# Verify required variables
for var in RDS_ENDPOINT DB_NAME DB_USER DB_PASSWORD MOODLE_URL; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Missing $var in .env"
        exit 1
    fi
done

# 1. Install Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update && sudo apt-get install -y curl
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

# 2. Set up Moodle files
MOODLE_DIR="$SCRIPT_DIR/moodlehtml"
if [ ! -d "$MOODLE_DIR" ] || [ -z "$(ls -A $MOODLE_DIR 2>/dev/null)" ]; then
    if [ -f "$SCRIPT_DIR/moodle-migration.tar.gz" ]; then
        mkdir -p "$MOODLE_DIR"
        tar -xzf "$SCRIPT_DIR/moodle-migration.tar.gz" -C "$SCRIPT_DIR"
        rm "$SCRIPT_DIR/moodle-migration.tar.gz"
    else
        echo "ERROR: moodlehtml directory or moodle-migration.tar.gz not found"
        exit 1
    fi
fi
sudo chown -R 33:33 "$MOODLE_DIR"
sudo chmod -R 755 "$MOODLE_DIR"

# 3. Test RDS connection
echo "Testing database connection..."
if ! mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" 2>/dev/null; then
    echo "ERROR: Cannot connect to RDS database"
    exit 1
fi

# 4. Start Docker containers
cd "$SCRIPT_DIR"
docker compose down 2>/dev/null || true
docker compose --env-file "$ENV_FILE" up -d

# 5. Wait for container ready
echo "Waiting for Moodle to start..."
for i in {1..30}; do
    if docker compose exec -T moodle curl -s http://localhost/index.php > /dev/null 2>&1; then
        echo "✓ Moodle is running"
        break
    fi
    sleep 2
done

# 6. Restore database if backup exists
if [ -f "$SCRIPT_DIR/migration-backup/moodle_backup.sql" ]; then
    read -p "Restore database from backup? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$SCRIPT_DIR/migration-backup/moodle_backup.sql"
        echo "✓ Database restored"
    fi
fi

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo "Access: $MOODLE_URL"
echo "Database: $DB_NAME on $RDS_ENDPOINT"
echo ""
echo "Commands:"
echo "  docker compose ps          # Status"
echo "  docker compose logs moodle # View logs"
echo "  docker compose restart moodle"
echo ""
