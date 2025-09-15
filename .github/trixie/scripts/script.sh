#!/bin/bash

# Init incus
sudo incus admin init --auto

PHP_VERSION=$1
mariaDBVersion=$2

# Launch Instance
sudo incus launch images:debian/trixie/amd64 tonics-lemp

# Dependencies
sudo incus exec tonics-lemp -- bash -c "apt update -y && apt upgrade -y && apt install -y curl apt-transport-https lsb-release"
sudo incus exec tonics-lemp -- bash -c "curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=$mariaDBVersion"

if (( $(echo "$PHP_VERSION > 8.3" | bc -l) )); then

  # Add Ondrej's repo source and signing key along with dependencies
  sudo incus exec tonics-lemp -- bash -c  "curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg"
  sudo incus exec tonics-lemp -- bash  <<HEREDOC
  echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(sudo incus exec tonics-lemp -- lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
HEREDOC

  sudo incus exec tonics-lemp -- bash -c "apt update -y"

fi

sudo incus exec tonics-lemp -- bash -c "DEBIAN_FRONTEND=noninteractive apt update -y && apt install -y mariadb-server nginx php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-{mysql,mbstring,readline,gd,gmp,bcmath,zip,curl,intl,apcu}"

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
Version="Lemp__$(sudo incus exec tonics-lemp -- mariadbd --version | awk '{print $3}' | sed 's/,//')__$(sudo incus exec tonics-lemp -- php -v | head -n 1 | awk '{print $2}' | cut -d '-' -f 1)-PHP__$(sudo incus exec tonics-lemp -- nginx -v |& sed 's/nginx version: nginx\///')-Nginx"

# Publish Image
mkdir images && sudo incus stop tonics-lemp && sudo incus publish tonics-lemp --alias tonics-lemp

# Export Image
sudo incus start tonics-lemp
sudo incus image export tonics-lemp images/$Version

# Image Info
sudo incus image info tonics-lemp >> images/info.txt
