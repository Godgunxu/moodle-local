#!/bin/bash
# SSL Certificate Setup for Moodle on Lightsail
# Installs Let's Encrypt certificate and configures Apache

set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 moodle.yourdomain.com"
    exit 1
fi

echo "================================"
echo "Setting up SSL for $DOMAIN"
echo "================================"

# Install Certbot
echo "Installing Certbot..."
sudo apt-get install -y -qq certbot python3-certbot-apache

# Stop containers temporarily
echo "Stopping Moodle container..."
docker compose down

# Get certificate
echo "Requesting certificate from Let's Encrypt..."
sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN -n --agree-tos --email admin@$DOMAIN

# Create SSL configuration directory
mkdir -p ssl-config

# Create Apache vhost configuration
cat > ssl-config/moodle-ssl.conf << EOF
# Redirect HTTP to HTTPS
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteCond %{HTTPS} off
        RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
    </IfModule>
</VirtualHost>

# HTTPS VirtualHost
<VirtualHost *:443>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    
    DocumentRoot /var/www/html
    
    # SSL Configuration
    SSLEngine on
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    
    # Security headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    # Moodle specific
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ /index.php?q=$1 [QSA,L]
        </IfModule>
    </Directory>
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

echo "Copying certificate files into volume..."
mkdir -p ./certificates

# Update docker-compose to mount certificates and SSL config
cat > docker-compose-ssl.override.yml << EOF
version: '3.8'

services:
  moodle:
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - ./ssl-config/moodle-ssl.conf:/etc/apache2/sites-available/moodle-ssl.conf:ro
EOF

echo "Setting up certificate auto-renewal..."
sudo systemctl enable certbot.timer

cat > /home/ubuntu/renew-ssl.sh << 'EOF'
#!/bin/bash
/usr/bin/certbot renew --quiet
systemctl restart docker
EOF

sudo chmod +x /home/ubuntu/renew-ssl.sh
(sudo crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/renew-ssl.sh") | sudo crontab -

# Restart containers
echo "Starting Moodle with SSL..."
docker compose up -d

# Wait for container
sleep 5

# Test certificate
echo ""
echo "Testing SSL configuration..."
openssl s_client -connect localhost:443 -servername $DOMAIN < /dev/null | grep "Verify return code"

echo ""
echo "================================"
echo "✓ SSL Setup Complete!"
echo "================================"
echo ""
echo "Certificate Details:"
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates
echo ""
echo "Access your Moodle at: https://$DOMAIN"
echo ""
echo "Certificate will auto-renew in 30 days"
echo ""
