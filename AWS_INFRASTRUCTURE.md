# AWS Infrastructure Setup Guide

Complete step-by-step guide to set up AWS resources before deploying Moodle.

## Prerequisites

- AWS Account (https://aws.amazon.com)
- Basic understanding of AWS Console
- Domain name (optional but recommended for production)
- SSH key management

---

## Step 1: Create RDS MariaDB Database

### 1.1 Navigate to RDS Console

1. AWS Console → Search "RDS" → Click **RDS Service**
2. Click **Databases** → **Create database**

### 1.2 Database Configuration

**Engine Selection**
- [ ] Select **MariaDB**
- [ ] Version: **10.11.latest** (or compatible version)
- [ ] License: MariaDB Community Edition

**Templates**
- [ ] Choose **Production** (safer) or **Dev/Test**
- For learning: Choose **Dev/Test** (lower cost)

**Settings**
- [ ] Deployment option: **Single DB instance**
- [ ] DB instance identifier: `moodle-db`
- [ ] Master username: `moodle`
- [ ] Master password: **Generate strong password** (save this!)
  - Copy to secure location: `[SAVE_PASSWORD]`
- [ ] Confirm password: Paste again

**Instance Configuration**
- [ ] DB instance class: **db.t3.micro** (Free tier eligible)
- [ ] Storage: **20 GB** (GP2)
- [ ] Storage autoscaling: **Enabled**

**Connectivity**
- [ ] VPC: Default VPC
- [ ] DB subnet group: **default**
- [ ] Public accessibility: **NO**
- [ ] VPC security group: **Create new** → Call it `moodle-rds-sg`
- [ ] Availability Zone: **No preference**

**Database Authentication**
- [ ] Authentication method: **Password authentication**

**Additional Configuration**
- [ ] Initial database name: `moodle`
- [ ] DB parameter group: **default.mariadb10.11** (or latest)
- [ ] Option group: **default**
- [ ] Backup retention period: **7 days**
- [ ] Backup window: **Automatic**
- [ ] Monitoring: **Enable Enhanced monitoring** (optional)
- [ ] Backup location: **Default**
- [ ] Enable encryption: **Yes**
- [ ] KMS key: **aws/rds** (default)
- [ ] Deletion protection: **Enable**

### 1.3 Create Database

1. Click **Create database**
2. Wait 5-10 minutes for creation to complete
3. Status will change from "Creating" to "Available"

### 1.4 Note RDS Details

When database is ready:
1. Click database name `moodle-db`
2. Note these details in your `.env` file:

```
RDS_ENDPOINT: [Connectivity & security → Endpoint]
DB_NAME: moodle
DB_USER: moodle
DB_PASSWORD: [Your saved password]
```

Example:
```
RDS_ENDPOINT=moodle-db.c9akciq32.us-east-1.rds.amazonaws.com
DB_NAME=moodle
DB_USER=moodle
DB_PASSWORD=GeneratedPassword123!
```

---

## Step 2: Create Lightsail Instance

### 2.1 Navigate to Lightsail Console

1. AWS Console → Search "Lightsail" → Click **Lightsail Service**
2. Click **Instances** → **Create instance**

### 2.2 Select Location

- [ ] Choose your region (MUST be same as RDS region)
- [ ] Availability Zone: **Any** (default)

### 2.3 Select Blueprint

- [ ] Platform: **Linux/Unix**
- [ ] OS: **Ubuntu 22.04 LTS**
- [ ] (Optional) Add Launch Script: Leave blank for now

### 2.4 Choose Instance Plan

Select your instance size:
- **$3.50/month**: 512 MB RAM, 1 vCPU (Recommended for testing)
- **$5/month**: 1 GB RAM, 1 vCPU
- **$10/month**: 2 GB RAM, 1 vCPU (Better for production)

### 2.5 Instance Name

- [ ] Instance name: `moodle-instance` (or your choice)

### 2.6 Create Instance

1. Click **Create instance**
2. Wait 2-3 minutes for startup
3. Status will show "Running" when ready

### 2.7 Attach Static IP

1. Instance details page → **Networking** tab
2. Scroll down → **Static IP**
3. Click **Attach static IP**
4. Attach to your instance
5. **Note the public IP address**

Example: `34.214.123.45`

---

## Step 3: Configure Security Groups

### 3.1 RDS Security Group Configuration

**Goal:** Allow Lightsail to connect to RDS on port 3306

1. AWS Console → **RDS** → **Databases** → `moodle-db`
2. **Connectivity & security** → Scroll to **VPC security groups**
3. Click the security group name `moodle-rds-sg`

**Add Inbound Rule:**
1. Click **Edit inbound rules**
2. Click **Add rule**
   - Type: **MySQL/Aurora**
   - Port: **3306**
   - Source: **Select Lightsail security group**
   - Source Security Group: Search for Lightsail's security group
   - Description: "Lightsail Moodle Access"
3. Click **Save**

### 3.2 Lightsail Security Group Configuration

**Goal:** Allow HTTP/HTTPS from internet, SSH from your IP

1. AWS Console → **Lightsail** → **Instances**
2. Click your instance → **Networking** tab
3. Scroll to **Firewall** section

**Current rules should show:**
- SSH (22) - from your connection IP

**Add new rules:**

Add Rule 1 (HTTP):
1. Click **+ Add rule**
   - Protocol: **HTTP**
   - Port: **80**
   - Source: **Anywhere** (0.0.0.0/0)
2. Click **✓**

Add Rule 2 (HTTPS):
1. Click **+ Add rule**
   - Protocol: **HTTPS**
   - Port: **443**
   - Source: **Anywhere** (0.0.0.0/0)
2. Click **✓**

**Optional: Restrict SSH for security**
1. Find SSH rule (port 22)
2. Change Source from "Anywhere" to your IP
3. Click **✓**

---

## Step 4: Create SSH Key Pair (if needed)

### 4.1 Download SSH Key

1. Lightsail Console → **Account** (bottom left)
2. Click **SSH keys** → **Default key pair**
3. If not already downloaded:
   - Click **Download default key pair**
   - Save `LightsailDefaultKey.pem` securely
   - Permissions: `chmod 400 LightsailDefaultKey.pem`

### 4.2 Create Additional Keys (Optional)

For better security with multiple users:

1. Lightsail → **Account** → **SSH keys**
2. Click **Create key pair**
3. Name: `moodle-deployment-key`
4. Download and secure the `.pem` file

---

## Step 5: Connect to Lightsail Instance

### 5.1 Using Browser Terminal (Easiest)

1. Lightsail Console → Your instance
2. Click **Connect** button (top right)
3. Browser terminal opens

### 5.2 Using SSH (Advanced)

```bash
# From your local machine
chmod 400 LightsailDefaultKey.pem
ssh -i LightsailDefaultKey.pem ubuntu@34.214.123.45
```

---

## Step 6: Test AWS Connectivity

### 6.1 SSH into Lightsail

1. Open browser terminal OR SSH from local machine

### 6.2 Test RDS Connection

```bash
# Install MySQL client
sudo apt-get update
sudo apt-get install -y mariadb-client

# Test connection to RDS
mysql -h moodle-db.c9akciq32.us-east-1.rds.amazonaws.com \
      -u moodle \
      -p

# When prompted, enter your RDS password
# Should show "MariaDB [(none)]>" prompt
# Type "exit" to disconnect
```

---

## Step 7: DNS Configuration (If Using Domain)

### 7.1 Add A Record to Your Domain

1. Go to your domain registrar (GoDaddy, Namecheap, Route 53, etc.)
2. Navigate to **DNS Settings**
3. Find **A Records**
4. Add/Edit:
   - **Name**: `@` (or your subdomain)
   - **Type**: **A**
   - **Value**: Your Lightsail static IP (e.g., `34.214.123.45`)
   - **TTL**: **3600** (or lower for faster updates)
5. **Save**

### 7.2 Verify DNS (Wait 5-15 minutes)

```bash
# Check DNS resolution
nslookup yourdomain.com
# Should show your Lightsail IP
```

---

## Step 8: Prepare for Deployment

### 8.1 Create .env File Locally

```bash
# On your LOCAL machine (not Lightsail)
cd ~/path-to-moodle-local/
cp .env.aws.example .env

# Edit with your values
nano .env
```

Fill in:
```env
RDS_ENDPOINT=moodle-db.c9akciq32.us-east-1.rds.amazonaws.com
DB_NAME=moodle
DB_USER=moodle
DB_PASSWORD=YourRDSPassword123!

MOODLE_URL=https://yourdomain.com
SITE_NAME=My Moodle Site
ADMIN_EMAIL=admin@yourdomain.com
AWS_REGION=us-east-1
```

### 8.2 Upload Files to Lightsail

```bash
# From local machine
scp -i LightsailDefaultKey.pem \
    -r moodlehtml \
    ubuntu@34.214.123.45:~/

scp -i LightsailDefaultKey.pem \
    .env \
    ubuntu@34.214.123.45:~/moodle-local/

scp -i LightsailDefaultKey.pem \
    deploy-aws-v2.sh verify-aws-config.sh backup-rds.sh \
    ubuntu@34.214.123.45:~/moodle-local/
```

---

## Step 9: Verify Everything Before Deployment

### 9.1 Basic Checks

- [ ] RDS database is "Available"
- [ ] Lightsail instance is "Running"
- [ ] Static IP is attached
- [ ] Security groups allow connections
- [ ] SSH access to Lightsail works
- [ ] MySQL client can connect to RDS
- [ ] .env file has all required variables
- [ ] Moodle files uploaded to Lightsail

### 9.2 Pre-Deployment Verification

SSH into Lightsail:

```bash
# Test RDS connection again
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASSWORD moodle -e "SELECT 1"

# Verify files
ls -la ~/moodlehtml/ | head
ls -la ~/moodle-local/.env

# Run verification script
cd ~/moodle-local
chmod +x verify-aws-config.sh
./verify-aws-config.sh
```

All checks should pass before proceeding.

---

## Cost Summary

| Item | Cost/Month | Notes |
|------|-----------|-------|
| Lightsail (512MB) | $3.50 | Minimum recommended |
| RDS (db.t3.micro) | Free (1 yr) then $15 | Eligible for free tier |
| Data Transfer | $0-5 | Usually minimal |
| Domain | $1-2 | Already purchased |
| **Total** | **$4-10** | First year only |

---

## Troubleshooting

### Cannot connect to RDS
- [ ] Verify RDS is in "Available" state
- [ ] Verify security group allows port 3306
- [ ] Verify password is correct
- [ ] Check RDS and Lightsail are in same region
- [ ] Try from Lightsail instance, not local machine

### Cannot SSH to Lightsail
- [ ] Verify instance is "Running"
- [ ] Verify SSH key has correct permissions: `chmod 400 key.pem`
- [ ] Try browser terminal in Lightsail console
- [ ] Check security group allows SSH (port 22)

### Wrong region selected
- [ ] RDS and Lightsail MUST be in same region
- [ ] Updates cannot be made - delete and recreate in correct region

---

## Next Steps

Once all infrastructure is ready:

1. ✅ SSH into Lightsail
2. ✅ Run `verify-aws-config.sh`
3. ✅ Run `deploy-aws-v2.sh`
4. ✅ Complete Moodle setup wizard
5. ✅ Configure SSL certificate
6. ✅ Set up backups
7. ✅ Monitor and maintain

See `AWS_DEPLOYMENT.md` for detailed deployment steps.
