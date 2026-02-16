#!/bin/bash
#
# AWS Moodle Configuration Validator
# Verifies all AWS settings before deployment
#
# Usage: ./verify-aws-config.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ AWS Moodle Configuration Validator    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0
WARNINGS=0

# ============================================
# Check 1: .env File Exists
# ============================================
echo -e "${YELLOW}Checking Configuration Files...${NC}"

if [ ! -f ".env" ]; then
    echo -e "${RED}✗ .env file not found${NC}"
    echo "  Create from template: cp .env.aws.example .env"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ .env file found${NC}"
fi

if [ ! -f ".env.aws.example" ]; then
    echo -e "${RED}✗ .env.aws.example template not found${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ .env.aws.example template found${NC}"
fi

if [ ! -f "docker-compose.aws.yml" ]; then
    echo -e "${RED}✗ docker-compose.aws.yml not found${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ docker-compose.aws.yml found${NC}"
fi

echo ""

# ============================================
# Check 2: Required Variables
# ============================================
echo -e "${YELLOW}Checking Environment Variables...${NC}"

if [ -f ".env" ]; then
    source .env
    
    # Check RDS settings
    if [ -z "$RDS_ENDPOINT" ]; then
        echo -e "${RED}✗ RDS_ENDPOINT not set${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ RDS_ENDPOINT: $RDS_ENDPOINT${NC}"
    fi
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}✗ DB_NAME not set${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ DB_NAME: $DB_NAME${NC}"
    fi
    
    if [ -z "$DB_USER" ]; then
        echo -e "${RED}✗ DB_USER not set${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ DB_USER: $DB_USER${NC}"
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        echo -e "${RED}✗ DB_PASSWORD not set${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ DB_PASSWORD: ••••••••${NC}"
    fi
    
    if [ -z "$MOODLE_URL" ]; then
        echo -e "${RED}✗ MOODLE_URL not set${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ MOODLE_URL: $MOODLE_URL${NC}"
        
        # Check if using HTTPS
        if [[ ! "$MOODLE_URL" =~ ^https:// ]]; then
            echo -e "${YELLOW}⚠ WARNING: Using HTTP instead of HTTPS${NC}"
            echo "  For production, use HTTPS with SSL certificate"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
else
    echo -e "${RED}✗ Cannot read .env file${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ============================================
# Check 3: File Structure
# ============================================
echo -e "${YELLOW}Checking File Structure...${NC}"

if [ -d "moodlehtml" ] && [ -f "moodlehtml/index.php" ]; then
    echo -e "${GREEN}✓ Moodle files present ($(find moodlehtml -type f | wc -l) files)${NC}"
else
    echo -e "${RED}✗ Moodle files not found or incomplete${NC}"
    echo "  Ensure moodlehtml/ directory contains Moodle source"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "migration-backup/moodle_backup.sql" ]; then
    SIZE=$(du -h migration-backup/moodle_backup.sql | cut -f1)
    echo -e "${GREEN}✓ Database backup found ($SIZE)${NC}"
else
    echo -e "${YELLOW}⚠ No database backup found${NC}"
    echo "  Fresh database will be created"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ============================================
# Check 4: Docker and Tools
# ============================================
echo -e "${YELLOW}Checking Required Tools...${NC}"

if command -v docker &> /dev/null; then
    VERSION=$(docker --version)
    echo -e "${GREEN}✓ Docker installed: $VERSION${NC}"
else
    echo -e "${RED}✗ Docker not found${NC}"
    echo "  Install Docker: curl -fsSL https://get.docker.com | sh"
    ERRORS=$((ERRORS + 1))
fi

if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
else
    echo -e "${RED}✗ Docker Compose not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

if command -v mysql &> /dev/null; then
    echo -e "${GREEN}✓ MySQL client installed${NC}"
else
    echo -e "${YELLOW}⚠ MySQL client not found${NC}"
    echo "  Install: sudo apt-get install mariadb-client"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ============================================
# Check 5: AWS Connectivity (if on Lightsail)
# ============================================
echo -e "${YELLOW}Checking AWS Configuration...${NC}"

# Check if running on AWS
if [ -f "/.dockerenv" ]; then
    echo -e "${BLUE}ℹ Running in Docker container${NC}"
elif curl -s http://169.254.169.254/latest/meta-data/ &> /dev/null; then
    echo -e "${GREEN}✓ Running on AWS${NC}"
    
    # Check if running on Lightsail
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    echo -e "${GREEN}✓ AWS Region: $AWS_REGION${NC}"
else
    echo -e "${YELLOW}⚠ Not running on AWS${NC}"
    echo "  This should be run on AWS Lightsail instance"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ============================================
# Check 6: Recommendations
# ============================================
echo -e "${YELLOW}Best Practices Check:${NC}"

# Check if using strong passwords
if [ -n "$DB_PASSWORD" ]; then
    if [ ${#DB_PASSWORD} -lt 12 ]; then
        echo -e "${YELLOW}⚠ DB_PASSWORD is short (${#DB_PASSWORD} chars)${NC}"
        echo "  Recommended: 12+ characters with mixed case, numbers, symbols"
        WARNINGS=$((WARNINGS + 1))
    elif [[ "$DB_PASSWORD" =~ [A-Z] ]] && [[ "$DB_PASSWORD" =~ [a-z] ]] && [[ "$DB_PASSWORD" =~ [0-9] ]] && [[ "$DB_PASSWORD" =~ [!@#$%^&*] ]]; then
        echo -e "${GREEN}✓ DB_PASSWORD meets security requirements${NC}"
    else
        echo -e "${YELLOW}⚠ DB_PASSWORD should include uppercase, lowercase, numbers, and symbols${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check git status
if git rev-parse --git-dir > /dev/null 2>&1; then
    if git status --porcelain | grep -q ".env"; then
        echo -e "${RED}✗ .env is tracked in git${NC}"
        echo "  Remove from git: git rm --cached .env"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓ .env is not tracked in git${NC}"
    fi
else
    echo -e "${BLUE}ℹ Not a git repository${NC}"
fi

echo ""

# ============================================
# Summary
# ============================================
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    fi
else
    echo -e "${RED}❌ $ERRORS error(s) found${NC}"
    echo "Please fix the errors above before deploying"
    exit 1
fi

echo ""
echo -e "${YELLOW}Ready to Deploy:${NC}"
echo "  1. Verify all settings are correct in .env"
echo "  2. Run: chmod +x deploy-aws-v2.sh"
echo "  3. Run: ./deploy-aws-v2.sh"
echo ""
