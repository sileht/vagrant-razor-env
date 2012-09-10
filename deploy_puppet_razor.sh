#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# wiki part
apt-get install -y puppet augeas-tools puppetmaster sqlite3 libsqlite3-ruby libactiverecord-ruby git libmysql-ruby mysql-server mysql-client rubygems

update-alternatives --set gem  /usr/bin/gem1.8
update-alternatives --set ruby  /usr/bin/ruby1.8

augtool << EOT
set /files/etc/puppet/puppet.conf/master/storeconfigs true
set /files/etc/puppet/puppet.conf/master/dbadapter mysql
set /files/etc/puppet/puppet.conf/master/dbname puppet
set /files/etc/puppet/puppet.conf/master/dbuser puppet
set /files/etc/puppet/puppet.conf/master/dbpassword password
set /files/etc/puppet/puppet.conf/master/dbserver localhost
set /files/etc/puppet/puppet.conf/master/dbsocket /var/run/mysqld/mysqld.sock
set /files/etc/puppet/puppet.conf/agent/pluginsync true
set /files/etc/puppet/puppet.conf/agent/server $(hostname -f)
save
EOT

mysqladmin create puppet
mysql -e "grant all on puppet.* to 'puppet'@'localhost' identified by 'password';"

echo '*' > /etc/puppet/autosign.conf

cd /etc/puppet/modules
git clone git://git.labs.enovance.com/puppet.git .
git checkout openstack
git submodule init
git submodule update

git rm -rf  sudo
sed -i '/nodejs/d' .gitmodules
git rm --cached nodejs
rm -rf nodejs
rm -rf .git/modules/nodejs

git submodule add https://github.com/puppetlabs/puppetlabs-mongodb.git mongodb
git submodule add https://github.com/puppetlabs/puppetlabs-dhcp dhcp
git submodule add https://github.com/puppetlabs/puppetlabs-tftp.git tftp
git submodule add https://github.com/puppetlabs/puppetlabs-apt.git apt
git submodule add https://github.com/puppetlabs/puppetlabs-ruby ruby
git submodule add https://github.com/puppetlabs/puppetlabs-nodejs nodejs
git submodule add https://github.com/saz/puppet-sudo.git sudo
git submodule add https://github.com/puppetlabs/puppetlabs-razor razor
git submodule add https://github.com/attachmentgenie/puppet-module-network.git network # warn master used

(cd mongodb && git checkout 0.1.0)
(cd apt && git checkout 0.0.4)
(cd nodejs && git checkout 0.2.0)
(cd dhcp && git checkout 1.1.0)
(cd tftp && git checkout 0.2.1)
(cd ruby && git checkout 0.0.2)
(cd sudo && git checkout v2.0.0)
(cd xinetd && git pull origin master) # not yet in wiki

# Held on the working nodejs
(cd nodejs && patch -p1 < /vagrant/nodejs.patch)

cd razor

git checkout master

# pending razor fix
curl https://github.com/puppetlabs/puppetlabs-razor/pull/48.patch | git am
curl https://github.com/puppetlabs/puppetlabs-razor/pull/64.patch | git am
patch -p1 < /vagrant/puppet_razor_broker_desc.patch # < not in wiki waiting for upstream fix in 48.patch

cd - 

# node js fixup
apt-get install libc-ares-dev libev-dev libssl-dev libv8-dev libv8-3.8.9.20 libev4 libc-ares2 zlib1g-dev libssl-doc
dpkg -i /vagrant/nodejs*.deb
echo 'nodejs hold' | dpkg --set-selections
echo 'nodejs-dev hold' | dpkg --set-selections
apt-get install -f -y

ln -sf /vagrant/site.pp /etc/puppet/manifests/site.pp
/etc/init.d/puppetmaster restart

puppet agent -vt



