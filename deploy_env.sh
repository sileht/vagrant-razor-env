#!/bin/bash

# APT CONFIG
cat > /etc/apt/apt.conf.d/90perso <<EOF
Acquire::PDiffs "false";
Acquire::Languages "none";
EOF

# puppet module nodejs use ftp.us.debian.org to install the nodejs package
cat > /etc/apt/sources.list <<EOF
deb http://192.168.100.1/debian/ wheezy main
deb http://ftp.us.debian.org/debian/ sid main
#deb http://192.168.100.1/security wheezy/updates main
EOF

echo >> /etc/hosts <<EOF
192.168.100.1 ftp.us.debian.org
EOF
export DEBIAN_FRONTEND=noninteractive

apt-get update -y

# PREFS
update-alternatives --set editor /usr/bin/vim.basic
ln -sf /vagrant/.bashrc /root/.bashrc
echo 'syn on' > /root/.vimrc

# Whooo is so quick
apt-get install -y eatmydata

cat > /etc/profile.d/eatmydata.sh <<EOF
export LD_PRELOAD=/usr/lib/libeatmydata/libeatmydata.so
EOF

. /etc/profile.d/eatmydata.sh

ip_eth1=$(ip -o -4 a  show dev eth1  | sed -n 's,.*inet \(.*\)/24.*,\1,p')
sed -i -e "s/127.0.1.1/$ip_eth1/" /etc/hosts

apt-get install -y dnsmasq curl vim screen git

git config --global user.email "sileht@sileht.net" 
git config --global user.name "Mehdi Abaakouk"



