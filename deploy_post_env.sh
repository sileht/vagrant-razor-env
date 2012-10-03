#!/bin/bash

cd /opt/razor/
patch -p1 < /vagrant/razor_preseed.local_repo.patch # < not in wiki this my debian repo :)
patch -p1 < /vagrant/razor_improve_post_install_status-186.patch
patch -p1 < /vagrant/razor_force_loglevel.rb
patch -p1 < /vagrant/razor_wait_link_configuration.patch
patch -p1 < /vagrant/razor_debian_puppet.patch
patch -p1 < /vagrant/razor_eatmydata_puppet.patch
/opt/razor/bin/razor_daemon.rb restart

gem install rspec
gem install rspec-puppet
gem install rake

git clone git://github.com/puppetlabs/puppetlabs_spec_helper.git /root/puppetlabs_spec_helper
cd /root/puppetlabs_spec_helper
rake package:gem
gem install pkg/puppetlabs_spec_helper-*.gem


cd /etc/puppet/modules/razor
git remote add sileht git@github.com:sileht/puppetlabs-razor.git
#git fetch sileht

cd /opt/razor/
git remote add sileht git@github.com:sileht/Razor.git
git remote add upstream http://github.com/puppetlabs/Razor.git
git remote add lynxbat https://github.com/lynxbat/Razor.git
#git fetch sileht
git fetch upstream

