#!/bin/bash

# Init incus
sudo incus admin init --auto

# Launch Instance
sudo incus launch images:debian/bookworm/amd64 tonics-lemp

# Dependencies
sudo incus exec tonics-lemp -- bash -c "apt update -y && apt upgrade -y"

sudo incus exec tonics-lemp -- bash -c "DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server nginx php php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-readline php8.2-gd  php8.2-gmp php8.2-bcmath  php8.2-zip php8.2-curl php8.2-intl php8.2-apcu"

# Setup MariaDB
sudo incus exec tonics-lemp -- bash -c "mysql --user=root -sf <<EOS
-- set root password
ALTER USER root@localhost IDENTIFIED BY 'tonics_cloud';
DELETE FROM mysql.user WHERE User='';
-- delete remote root capabilities
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- drop database 'test'
DROP DATABASE IF EXISTS test;
-- also make sure there are lingering permissions to it
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- make changes immediately
FLUSH PRIVILEGES;
EOS
"

# Start Nginx
sudo incus exec tonics-lemp -- bash -c "sudo nginx"

# Clean Debian Cache
sudo incus exec tonics-lemp -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

# Version
Version="Lemp__$(sudo incus exec tonics-lemp -- mysql -V | awk '{print $5}' | sed 's/,//')__$(sudo incus exec tonics-lemp -- php -v | head -n 1 | awk '{print $2}' | cut -d '-' -f 1)-PHP__$(sudo incus exec tonics-lemp -- nginx -v |& sed 's/nginx version: nginx\///')-Nginx"

# Publish Image
mkdir images && sudo incus stop tonics-lemp && sudo incus publish tonics-lemp --alias tonics-lemp

# Export Image
sudo incus start tonics-lemp
sudo incus image export tonics-lemp images/$Version

# Image Info
sudo incus image info tonics-lemp >> images/info.txt
