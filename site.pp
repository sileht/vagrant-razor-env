# vim:set ft=rb:

node /^puppet/ {

	dhcp::pool{ 'razor.lan':
		network => '192.168.100.0',
		mask    => '255.255.255.0',
		range   => '192.168.100.150 192.168.100.200',
		gateway => '192.168.100.1',
	}
	class { 'dhcp':
		dnsdomain   => [
			'razor.lan',
			'100.168.192.in-addr.arpa',
			],
		nameservers => [$ipaddress_eth1],
		interfaces  => ['eth1'],
		ntpservers  => ['us.pool.ntp.org'],
		pxeserver   => $ipaddress_eth1,
		pxefilename => 'pxelinux.0',
	}

	class { 'sudo':
		config_file_replace => false,
	}    
	class { 'razor': 
		address => $ipaddress_eth1,
		mk_name => "rz_mk_prod-image.0.9.0.5.iso",
		mk_source => "/vagrant/rz_mk_prod-image.0.9.0.5.iso",
  		server_opts_hash => { 'mk_log_level' => 'Logger::DEBUG' },
		git_source => "https://github.com/sileht/Razor.git",
		git_revision => "master",
	}

	rz_image { "debian-wheezy-netboot-amd64.iso":
		ensure  => present,
		type    => 'os',
		version => '7.0b1',
#		source  => "http://ftp.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/netboot/mini.iso",
		source  => "/vagrant/mini.iso",
	}

	rz_model { 'controller_model':
	  ensure      => present,
	  description => 'Controller Wheezy Model',
	  image       => 'debian-wheezy-netboot-amd64.iso',
	  metadata    => {'domainname' => 'razor.lan', 'hostname_prefix' => 'controller', 'root_password' => 'password'},
	  template    => 'debian_wheezy',
	}

	rz_model { 'compute_model':
	  ensure      => present,
	  description => 'Compute Wheezy Model',
	  image       => 'debian-wheezy-netboot-amd64.iso',
	  metadata    => {'domainname' => 'razor.lan', 'hostname_prefix' => 'compute', 'root_password' => 'password'},
	  template    => 'debian_wheezy',
	}
	
	rz_broker { 'puppet_broker':
	  ensure      => present,
	  description => 'puppet',
	  plugin      => 'puppet',
          servers     => [ "$fqdn" ]
	}

	rz_policy { 'controller_policy':
	  ensure  => present,
	  broker  => 'puppet_broker',
	  model   => 'controller_model',
	  enabled => 'true',
	  tags    => ['memsize_500MiB','nics_2'],
	  template => 'linux_deploy',
	  maximum => 1,
	}

	rz_policy { 'compute_policy':
	  ensure  => present,
	  broker  => 'puppet_broker',
	  model   => 'compute_model',
	  enabled => 'true',
	  tags    => ['memsize_1015MiB','nics_2'],
	  template => 'linux_deploy',
	  maximum => 3,
	}

}

class openstack_network {
        class { "network::interfaces":
          interfaces => {
            "eth0" => {
              "method" => "static",
              "address" => $ipaddress_eth0,
              "netmask" => "255.255.255.0",
            },
            "eth1" => {
              "method" => "static",
              "address" => $ipaddress_eth1,
              "netmask" => "255.255.255.0",
              "gateway" => "192.168.100.1"
            },
          },
          auto => ["eth0", "eth1"],
        }
}


###
# params needed by compute & controller
###

# The fqdn of the proxy host
$api_server = 'proxy.razor.lan'

# Networking strategy
$network_manager = 'nova.network.manager.FlatDHCPManager'
$multi_host_networking = true

# Mysql database root password
$db_rootpassword = 'dummy_password'

## Nova

# Nova db config
$db_password = 'dummy_nova_password'
$db_name = 'nova'
$db_user = 'nova'
$db_host = '192.168.100.100' # the private interface !!!
$db_allowed_hosts = ['192.168.100.%'] # private interfaces !!!

# Rabbitmq config
$rabbit_host = $api_server

# Hypervisor choice
$libvirt_type = 'qemu'

# nova user declared in keystone
$nova_auth = 'nova'
$nova_pass = 'nova_pass'

## Keystone

# Keystone db config
$keystone_db_password = 'dummy_keystone_password'
$keystone_db_name = 'keystone'
$keystone_db_user = 'keystone'

# Keystone admin credendials
$keystone_admin_token = 'admin_token'
$keystone_admin_email = 'test@example.com'
$keystone_admin_pass = 'admin_pass'

# Keystone services tenant (_/!\_ do not change _/!\_)
$ks_services_tenant = 'services'

## Glance

# Glance host
$glance_host = $api_server

# Glance db config
$glance_db_password = 'dummy_glance_password'
$glance_db_name = 'glance'
$glance_db_user = 'glance'

# glance user declared in keystone
$glance_auth = 'glance'
$glance_pass = 'glance_pass'

###
# Overrides
###

# Specify a sane default path for Execs
Exec {
  path      => '/usr/bin:/usr/sbin:/bin:/sbin',
  logoutput => true,
}

# Purge variables not explicitly set in this manifest
resources { 'nova_config':
  purge => true,
}

###
# Default node - configuration common to all nodes
###

node default {
}


###
# Controller node
###

class role_nova_controller_multihost{
  # We want our servers to be synchronized
  package { 'ntp':
    ensure => present,
  }

  ###
  # Mysql server, required by nova, keystone & glance
  ###
  class { 'mysql::server':
    config_hash => {
      # eth1 is our private network interface
      bind_address  => $ipaddress_eth1,
      root_password => $db_rootpassword,
    }
  }

  ###
  # Keystone
  ###

  class { 'keystone::db::mysql':
    password => $keystone_db_password,
    dbname   => $keystone_db_name,
    user     => $keystone_db_user,
    host     => 'localhost',
    require  => Class['mysql::server'],
  }

  class { 'keystone':
    admin_token  => $keystone_admin_token,
    log_verbose  => true,
    log_debug    => true,
    compute_port => 8774,
    catalog_type => 'sql'
  }

  class { 'keystone::config::mysql':
    user     => $keystone_db_user,
    password => $keystone_db_password,
    host     => 'localhost',
    dbname   => $keystone_db_name,
  }
  Class['keystone::db::mysql'] -> Class['keystone::config::mysql']

  # Creates an 'admin' keystone user in tenant named 'openstack'
  class { 'keystone::roles::admin':
    email    => $keystone_admin_email,
    password => $keystone_admin_pass,
  }
  Class['keystone'] -> Class['keystone::roles::admin']
  Class['keystone::config::mysql'] -> Class['keystone::roles::admin']

  class { 'keystone::endpoint':
    public_address   => $api_server,
    internal_address => $api_server,
    admin_address    => $api_server,
  }

  ###
  # Nova
  ###

  class { 'nova::rabbitmq':
  }

  class { 'nova::db::mysql':
    # pass in db config as params
    password      => $db_password,
    dbname        => $db_name,
    user          => $db_user,
    host          => 'localhost',
    allowed_hosts => $db_allowed_hosts,
    require       => Class['mysql::server'],
  }

  class { "nova":
    sql_connection        => "mysql://${db_user}:${db_password}@$localhost/${db_name}?charset=utf8",
    image_service         => 'nova.image.glance.GlanceImageService',
    glance_api_servers    => "${glance_host}:9292",
    rabbit_host           => $rabbit_host,
    verbose               => $verbose,
  }
  Class['nova::db::mysql'] -> Class['nova']

  class { "nova::api":
    enabled           => true,
    auth_host         => $api_server,
    admin_tenant_name => $admin_tenant_name,
    admin_user        => $nova_auth,
    admin_password    => $nova_pass,
  }

  class { "nova::objectstore":
    enabled => true,
  }

  class { "nova::cert":
    enabled => true,
  }

  # NOTE(fcharlier): to be included in Class['nova'] ?
  nova_config { "my_ip": value => $ipaddress_eth0 }

  class { "nova::scheduler": enabled => true }

  class { "nova::vncproxy": enabled => true }

  class { "nova::consoleauth": enabled => true }

  class { "nova::keystone::auth":
    auth_name        => $nova_auth,
    password         => $nova_pass,
    public_address   => $api_server,
    admin_address    => $api_server,
    internal_address => $api_server,
  }
  Class['keystone::roles::admin'] -> Class['nova::keystone::auth']

  nova_config { 'multi_host': value => $multi_host_networking }

  class { 'nova::network':
    private_interface => 'eth1',
    public_interface  => 'eth0',
    fixed_range       => '169.254.100.0/24',
    num_networks      => 1,
    floating_range    => false,
    network_manager   => $network_manager,
    config_overrides  => {
      flat_interface  => 'eth1',
    },
    create_networks   => true,
    enabled           => false,
    install_service   => false,
  }

  ###
  # Glance
  ###

  class { 'glance::keystone::auth':
    auth_name        => $glance_auth,
    password         => $glance_pass,
    public_address   => $api_server,
    admin_address    => $api_server,
    internal_address => $api_server,
  }
  Class['keystone::roles::admin'] -> Class['nova::keystone::auth']

  class { 'glance::api':
    log_verbose       => 'True',
    log_debug         => 'True',
    auth_type         => 'keystone',
    auth_host         => $api_server,
    auth_uri          => "http://${api_server}:5000/v2.0/",
    keystone_tenant   => $ks_services_tenant,
    keystone_user     => $glance_auth,
    keystone_password => $glance_pass,
  }

  class { 'glance::backend::file':
  }

  class { 'glance::db::mysql':
    password       => $glance_db_password,
    dbname         => $glance_db_name,
    user           => $glance_db_user,
    host           => 'localhost',
    require        => Class['mysql::server'],
  }

  class { 'glance::registry':
    log_verbose       => 'True',
    log_debug         => 'True',
    auth_type         => 'keystone',
    keystone_tenant   => $ks_services_tenant,
    keystone_user     => $glance_auth,
    keystone_password => $glance_pass,
    sql_connection    => "mysql://${glance_db_user}:${glance_db_password}@localhost/${glance_db_name}"
  }

  ###
  # rcfile for tests
  ###
  file { '/root/openrc.sh':
    ensure  => present,
    group   => 0,
    owner   => 0,
    mode    => '0600',
    content => "export OS_PASSWORD=${keystone_admin_pass}
export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/
export OS_USERNAME=admin
export OS_TENANT_NAME=openstack
"
  }

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  class { 'horizon':
    secret_key        => 'mah',
    cache_server_ip   => '127.0.0.1',
    cache_server_port => '11211',
    horizon_app_links => false,
  }

  file { '/etc/apache2/sites-available/horizon':
    owner   => 'root',
    group   => 'root',
    content => '
WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
WSGIDaemonProcess openstack-dashboard user=horizon group=horizon
WSGIProcessGroup openstack-dashboard

<Directory />
  AllowOverride None
</Directory>

<Directory /usr/share/openstack-dashboard/openstack_dashboard/wsgi/>
  Order allow,deny
  Allow from all
</Directory>

Alias /static/horizon /usr/share/pyshared/horizon/static/horizon

<Directory /usr/share/pyshared/horizon/static/horizon>
  Order allow,deny
  Allow from all
</Directory>

Alias /static /usr/share/openstack-dashboard/openstack_dashboard/static

<Directory /usr/share/openstack-dashboard/openstack_dashboard/static/>
  Order allow,deny
  Allow from all
</Directory>
',
    require => Package['apache2'],
    notify  => Exec['a2ensite horizon'],
  }


  exec { 'a2ensite horizon':
    refreshonly => true,
    notify      => Service['httpd']
  }
  exec { 'a2dissite openstack-dashboard':
    notify  => Service['httpd'],
  }

}

class role_nova_compute_multihost {

  # We want our cluster to be synchronized
  package { 'ntp':
    ensure => present,
  }

  # NOTE(fcharlier): to be included in Class['nova'] ?
  nova_config { "my_ip": value => $ipaddress_eth0 }
  nova_config { "routing_source_ip": value => $ipaddress_eth0 }

  class { 'nova':
    verbose                       => true,
    sql_connection                => "mysql://${db_user}:${db_password}@${db_host}/${db_name}?charset=utf8",
    rabbit_host                   => $rabbit_host,
    image_service                 => 'nova.image.glance.GlanceImageService',
    glance_api_servers            => "${glance_host}:9292",
  }
  class { 'nova::compute':
    enabled                       => true,
    vncserver_proxyclient_address => $ipaddress_eth0,
    vncproxy_host                 => $api_server,
  }
  class { 'nova::compute::libvirt':
    libvirt_type     => $libvirt_type,
    vncserver_listen => $ipaddress_eth0,
  }

  include 'keystone::python'

  nova_config {
    'multi_host'                      : value => $multi_host_networking;
    'enabled_apis'                    : value => 'metadata';
    'dhcp_lease_time'                 : value => 600; # set the lease tome to 10 minutes (defaults to 2 minutes)
    'libvirt_use_virtio_for_bridges'  : value => true; # Virtio networking
    'resume_guests_state_on_host_boot': value => true;
  }

  class { 'nova::network':
    private_interface => 'eth1',
    public_interface  => 'eth0',
    fixed_range       => '192.168.100.0/24',
    floating_range    => false,
    network_manager   => $network_manager,
    config_overrides  => {
      flat_interface  => 'eth1',
    },
    create_networks => false,
    enabled         => true,
    install_service => true,
  }

  # FIXME: to be included in the nova module ?
  # NOTE: inspired from http://projects.puppetlabs.com/projects/1/wiki/Kernel_Modules_Patterns
  # Activate nbd module (for qemu-nbd)
  exec { "insert_module_nbd":
    command => "/bin/echo 'nbd max-part=64' > /etc/modules",
    unless  => "/bin/grep 'nbd' /etc/modules",
  }
  exec { "/sbin/modprobe nbd max-part=64":
    unless => "/bin/grep -q '^nbd ' '/proc/modules'"
  }
}

node /^controller/ {	
	$ipaddress_eth0 = "10.142.6.33"
	$ipaddress_eth1 = "192.168.100.100"
	$ipaddress = $ipaddress_eth0

	exec{"killall dhclient": onlyif => "pidof dhclient" }
	class {"openstack_network": }

	include role_nova_controller_multihost

}

node /^compute/ {

	$nodeid = split($hostname, 'compute')
	$ipaddress_eth0 = "10.142.6.3$nodeid"
	$ipaddress_eth1 = "192.168.100.3$nodeid"
	$ipaddress = $ipaddress_eth0
	
	exec{"killall dhclient": onlyif => "pidof dhclient" }
	class {"openstack_network": }

	include role_nova_compute_multihost
}
