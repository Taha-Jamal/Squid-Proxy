#!/bin/bash

set -e

sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

yum -y update

yum install -y squid httpd-tools

systemctl start squid
systemctl enable squid

firewall-cmd --permanent --add-port=3128/tcp
firewall-cmd --reload

read -p "Enter the username for the proxy: " USERNAME
read -s -p "Enter the password for the proxy: " PASSWORD
echo

htpasswd -bc /etc/squid/passwd "$USERNAME" "$PASSWORD"
chown squid:squid /etc/squid/passwd
chmod 640 /etc/squid/passwd

read -p "Enter the IP range for your local network (e.g., 192.168.1.0/24): " LOCALNET

touch /etc/squid/blocksites
chown squid:squid /etc/squid/blocksites
chmod 640 /etc/squid/blocksites

cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
cat <<EOL > /etc/squid/squid.conf
# Squid Proxy Configuration

# Define Local Network
acl localnet src $LOCALNET    
acl localhost src 127.0.0.1/32

# Blocked Sites
acl blocksites url_regex "/etc/squid/blocksites"

# Allow Ports
acl Safe_ports port 80               # HTTP
acl Safe_ports port 443              # HTTPS

# Allow CONNECT method for HTTPS
acl CONNECT method CONNECT

# User Authentication
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Squid Proxy Server
auth_param basic credentialsttl 12 hours
acl authenticated proxy_auth REQUIRED
http_access deny !authenticated

# Access Control Rules
http_access deny blocksites              
http_access allow localhost              
http_access allow localnet               
http_access allow authenticated          
http_access deny !Safe_ports             
http_access deny CONNECT !Safe_ports     
http_access deny all                     

# Proxy Listening Port
http_port 3128                           

# Logging and Cache
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid            

# Refresh Patterns
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOL

systemctl restart squid

echo "Squid proxy setup complete."
