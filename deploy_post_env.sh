#!/bin/bash

cd /opt/razor/
patch -p1  < /vagrant/preseed.local_repo.patch # < not in wiki this my debian repo :)
/opt/razor/bin/razor_daemon.rb restart

gem install rspec
gem install rspec-puppet

git clone git://github.com/puppetlabs/puppetlabs_spec_helper.git
cd puppetlabs_spec_helper
rake package:gem
gem install pkg/puppetlabs_spec_helper-*.gem

