# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |env_config|

    env_config.vm.define "puppet" do |config|
        config.vm.box = "wheezy64"
        config.vm.host_name = "puppet.razor.lan"
        config.vm.network :hostonly, "192.168.100.2", :adapter => 2
        config.ssh.username = 'root'
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.vm.provision :shell, :path => "deploy_env.sh"
        config.vm.provision :shell, :path => "deploy_puppet_razor.sh"
        config.vm.provision :shell, :path => "deploy_post_env.sh"
    end

    env_config.vm.define "puppet2" do |config|
        config.vm.box = "wheezy64"
        config.vm.network :hostonly, "192.168.100.3", :adapter => 2
        config.vm.host_name = "puppet2.razor.lan"
        config.ssh.username = 'root'
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.vm.provision :shell, :path => "deploy_env.sh"
        config.vm.provision :shell, :path => "deploy_puppet_razor.sh"
    end

    env_config.vm.define "compute1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.11", :adapter => 1, :mac => "080027649A11"
        config.vm.network :hostonly, "192.168.100.61", :adapter => 2, :mac => "080027649B11"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "compute2" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.12", :adapter => 1, :mac => "080027649A12"
        config.vm.network :hostonly, "192.168.100.62", :adapter => 2, :mac => "080027649B12"
        config.vm.customize ["modifyvm", :id, "--memory", 1024]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "controller1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.22", :adapter => 1, :mac => "080027649A22"
        config.vm.network :hostonly, "192.168.100.72", :adapter => 2, :mac => "080027649B22"
        config.vm.host_name = "controller1.razor.lan"
        config.vm.customize ["modifyvm", :id, "--memory", 512]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

    env_config.vm.define "mgmt1" do |config|
        config.vm.box = "pxe"
        config.vm.network :hostonly, "192.168.100.21", :adapter => 1, :mac => "080027649A21"
        config.vm.network :hostonly, "192.168.100.71", :adapter => 2, :mac => "080027649B21"
        config.vm.host_name = "mgmt1.razor.lan"
        config.vm.customize ["modifyvm", :id, "--memory", 5000]
        config.ssh.port = 22
        config.ssh.max_tries = 0
        config.vm.boot_mode = :gui
    end

end
