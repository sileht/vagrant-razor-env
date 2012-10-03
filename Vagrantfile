# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |env_config|

    env_config.vm.define "puppet" do |config|
        config.vm.box = "wheezy64"
        config.vm.host_name = "puppet.razor.lan"
        config.vm.network :hostonly, "192.168.100.2", :adapter => 2
        config.ssh.username = 'root'
        config.vm.customize ["modifyvm", :id, "--memory", 2048]
#        config.vm.provision :shell, :path => "deploy_env.sh"
#        config.vm.provision :shell, :path => "deploy_puppet_razor.sh"
#        config.vm.provision :shell, :path => "deploy_post_env.sh"
    end

    env_config.vm.define "mon1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.11", :adapter => 1, :mac => "080027649A11"
        config.vm.network :hostonly, "192.168.100.61", :adapter => 2, :mac => "080027649B11"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "osd1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A12"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B12"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "client1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.22", :adapter => 1, :mac => "080027649A13"
        config.vm.network :hostonly, "192.168.100.72", :adapter => 2, :mac => "080027649B13"
        config.vm.customize ["modifyvm", :id, "--memory", 1536]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "lb1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A14"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B14"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "rgw1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A15"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B15"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "controller1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A16"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B16"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
#        config.vm.boot_mode = :gui
    end

    env_config.vm.define "compute1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A17"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B17"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
#        config.vm.boot_mode = :gui
    end
end
