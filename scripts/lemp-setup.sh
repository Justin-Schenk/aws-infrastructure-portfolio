#!/usr/bin/env bash
# lemp-setup.sh
# Idempotent LEMP stack setup for Amazon Linux 2023.
# Can be run standalone or called from CloudFormation UserData.
#
# Usage:
#   sudo DB_NAME=myapp DB_USER=appuser DB_PASS=secret bash lemp-setup.sh
#
# Environment variables:
#   DB_NAME   Database name to create (default: appdb)
#   DB_USER   MariaDB user to create (default: appuser)
#   DB_PASS   Password for DB_USER (required)

set -euo pipefail

DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASS="${DB_PASS:?DB_PASS is required}"

log() { echo "[lemp-setup] $*"; }

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
log "Installing packages..."
dnf update -y
dnf install -y nginx mariadb105-server php8.2 php8.2-fpm php8.2-mysqlnd

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------
log "Enabling services..."
systemctl enable --now nginx
systemctl enable --now mariadb
systemctl enable --now php-fpm

# ---------------------------------------------------------------------------
# MariaDB setup (idempotent: CREATE IF NOT EXISTS)
# ---------------------------------------------------------------------------
log "Configuring MariaDB..."
mysql -u root <<SQL
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

# ---------------------------------------------------------------------------
# Nginx PHP-FPM configuration
# ---------------------------------------------------------------------------
log "Writing Nginx config..."
cat > /etc/nginx/conf.d/lemp.conf <<'NGINXCONF'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXCONF

nginx -t
systemctl reload nginx

# ---------------------------------------------------------------------------
# Verification page
# ---------------------------------------------------------------------------
mkdir -p /var/www/html
cat > /var/www/html/index.php <<PHPEOF
<?php
phpinfo();
?>
PHPEOF

log "LEMP setup complete. Verify at http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"
