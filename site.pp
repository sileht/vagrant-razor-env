# vim:set ft=rb:

$ceph_domain = "ceph.lan"
$eth0_prefix = "10.0.2"
$eth1_prefix = "192.168.100"
$eth1_prefix_reverse = "100.168.192"
$gateway = "192.168.100.2" # ip du controller
$aptproxy = "192.168.100.1" # ip du controller
$password = 'password'

$instances_per_server = {
    "osdhigh" => 12,
    "osdmed" => 6,
    "osdlow" => 6,
    "client" => 6,
    "mon" => 3,
    "lb" => 3,
    "rgw" => 3,

}

# IP convention:
# osdhigh-1 : $eth1_prefix.11
# osdhigh-12 : $eth1_prefix.112
# osdmed-2 : $eth1_prefix.22
# osdlow-1 : $eth1_prefix.31
# client-5 : $eth1_prefix.45

$server_subprefix = {
    "osdhigh" => 1,
    "osdmed" => 2,
    "osdlow" => 3,
    "client" => 4,
    "mon" => 5,
    "lb" => 6,
    "rgw" => 7,
}

node /^osd/ inherits ceph_base {
    class{"ceph": }
}

node /^mon-/ inherits ceph_base {
    class{"ceph": }
}

node /^rgw-/ inherits ceph_base {
    class{"ceph": rgw => true, }
}

node /^lb-/ inherits ceph_base {
}

node /^client-/ inherits ceph_base {
    package {"rest-bench":}
    package {"swift":}
    package {"tsung":}

}
node /^puppet/ inherits controller_base {

    ceph_system { "mon": 
        tag_matcher => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:11',
            'inverse' => "false",
        } ],
    }

    ceph_system { "osdlow": 
        tag_matcher => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:12',
            'inverse' => "false",
        } ],
    }

    ceph_system { "client": 
        tag_matcher => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:13',
            'inverse' => "false",
        } ],
    }

    ceph_system { "osdmed":
        tag_matcher  => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:23',
            'inverse' => "false",
        } ],
    }

    ceph_system { 'osdhigh':
        tag_matcher  => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:18',
            'inverse' => "false",
        } ],
    }

    ceph_system { 'lb':
        tag_matcher  => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:14',
            'inverse' => "false",
        } ],
    }

    ceph_system { 'rgw':
        tag_matcher  => [
        { 'key'     => 'macaddress_eth1',
            'compare' => 'equal',
            'value'   => '08:00:27:64:9B:15',
            'inverse' => "false",
        } ],
    }

}

define ceph_system( $tag_matcher = [] ){
    razor::system { $name:
        hostprefix => "${name}-",
        domain => "$ceph_domain",
        password     => "$password",
        instances => $instances_per_server[$name],
        image => 'debian',
        broker => 'puppet',
        model_template  => 'debian_wheezy',
        tag_matcher  => $tag_matcher,
    }
}

node base {
    # Override path globally for all exec resources later
    Exec { path => '/usr/bin:/usr/sbin/:/bin:/sbin' }

    apt::source { "debian_addons":
        location          => "http://$gateway:3142/debian/",
        release           => "wheezy",
        repos             => "contrib non-free",
        required_packages => "debian-keyring debian-archive-keyring",
        key               => "55BE302B",
        key_server        => "subkeys.pgp.net",
        pin               => "-10",
        include_src       => true
    }

    package {"dstat":}
    package {"tcpdump":}
    package {"vim":}
    package {"screen":}
    package {"curl":}
    package {"fio":}
    package {"bonnie++":}
    package {"iozone3": 
        require => Apt::Source["debian_addons"]
    }
    package {"dmidecode":}

    package {"pdsh": }
    package {"xfsprogs": }

    file {"/root/.ssh":
        ensure => "directory",
        mode => 644,
    }
    file {"/root/.ssh/id_rsa":
        source => "puppet:///files/id_rsa",
        mode => "600",
    }
    file {"/root/.ssh/id_rsa.pub":
        source => "puppet:///files/id_rsa.pub",
        mode => "600",
    }
}

node ceph_base inherits base {
    $nodeid = inline_template("<%= hostname.split('-')[-1] %>") 
    $nodetype = inline_template("<%= server_subprefix[hostname.split('-')[-2]] %>") 

    # override facter value with new ip address
    $ipaddress_eth0 = "${eth0_prefix}.${nodetype}${nodeid}"
    $ipaddress_eth1 = "${eth1_prefix}.${nodetype}${nodeid}"
    $ipaddress = $ipaddress_eth0

    exec{"killall dhclient": onlyif => "pidof dhclient" }

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

    file {"/root/.ssh/authorized_keys":
        source => "puppet:///files/authorized_keys",
        mode => 644,
    }

}


node controller_base inherits base {
    package {"apt-cacher-ng": }
    service {"apt-cacher-ng": require => Package["apt-cacher-ng"] }
    package {"dnsmasq": }
    service {"dnsmasq": require => Package["dnsmasq"] }

    file {"/etc/hosts":
        content => inline_template('
127.0.0.1   localhost
<%= ipaddress_eth1 %> <%= fqdn %> <%= hostname %> puppet.<%= domain %> puppet

<%= aptproxy %> apt-cacher-ng

<% instances_per_server.each do |name, nb| (Range.new(1,nb.to_i)).each do |i| -%>
<%= eth1_prefix %>.<%= server_subprefix[name] %><%= i %> <%= name %>-adm-<%= i %>.<%= ceph_domain %> <%= name %>-adm-<%= i %>
<% end end -%>

<% instances_per_server.each do |name, nb| (Range.new(1,nb.to_i)).each do |i| -%>
<%= eth0_prefix %>.<%= server_subprefix[name] %><%= i %> <%= name %>-<%= i %>.<%= ceph_domain %> <%= name %>-<%= i %>
<% end end -%>
'),
        notify => Service["dnsmasq"],
        require => Package["dnsmasq"],
    }
    
    file {"/root/.ssh/config":
        content => "
Host *
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking=no
"
    }

    exec { "set_masq":
        command => "/sbin/iptables -t nat -A POSTROUTING -s ${eth1_prefix}.0/24 ! -d ${eth1_prefix}.0/24 -j MASQUERADE",
        refreshonly => true,
        subscribe => File["/etc/rc.local"],
    }
    exec { "set_forward":
        command => "/bin/echo 1 > /proc/sys/net/ipv4/ip_forward",
        refreshonly => true,
        subscribe => File["/etc/rc.local"],
    }

    file { "/etc/rc.local":
        content => "
#!/bin/sh
echo 1 > /proc/sys/net/ipv4/ip_forward
/sbin/iptables -t nat -A POSTROUTING -s ${eth1_prefix}.0/24 ! -d ${eth1_prefix}.0/24 -j MASQUERADE
exit 0
"
    }

	dhcp::pool{ $ceph_domain:
		network => "${eth1_prefix}.0",
		mask    => '255.255.255.0',
		range   => "${eth1_prefix}.200 ${eth1_prefix}.250",
		gateway => "$ipaddress_eth1",
	}
	class { 'dhcp':
		dnsdomain   => [
			"$ceph_domain",
			"${eth1_prefix_reverse}.in-addr.arpa",
		],
		nameservers => [$ipaddress_eth1],
		interfaces  => ['eth1'],
		ntpservers  => [$ipaddress_eth1,],
		pxeserver   => $ipaddress_eth1,
		pxefilename => 'pxelinux.0',
	}

	class { 'sudo':
		config_file_replace => false,
	}    
	class { 'razor': 
		address => $ipaddress_eth1,
        mk_name => 'rz_mk_dev-image.0.9.1.6.iso',
        mk_source => 'https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_dev-image.0.9.1.6.iso',
#  		server_opts_hash => { 'mk_log_level' => 'Logger::DEBUG' },
		git_source => "https://github.com/sileht/Razor.git",
		git_revision => "poc",
    }

	rz_image { "debian":
		ensure  => present,
		type    => 'os',
		version => '7.0b1',
		source  => "/vagrant/mini.iso",
	}

	rz_broker { 'puppet':
	    ensure      => present,
	    plugin      => 'puppet',
        servers     => [ "$fqdn" ]
	}
}

#
# CEPH 
# 
class ceph(
    $rgw = false,
){

    # common part
    apt::source{'ceph-repo':
        location => 'http://ceph.com/debian/',
        key => "17ED316D",
        key_source => "https://raw.github.com/ceph/ceph/master/keys/release.asc"
    }

    package {"ceph-common": ensure => latest, require => Apt::Source["ceph-repo"] }
    package {"ceph": ensure => latest, require => Apt::Source["ceph-repo"] }
    package {"librbd1": ensure => latest, require => Apt::Source["ceph-repo"] }
    package {"librados2": ensure => latest, require => Apt::Source["ceph-repo"] }
    package {"libcephfs1": ensure => latest, require => Apt::Source["ceph-repo"] }

    if $rgw {

        package {"radosgw": ensure => latest, require => Apt::Source["ceph-repo"] }
        package {"apache2": }
        package {"libapache2-mod-fastcgi": 
            require => [ 
                Package["apache2"],
                Apt::Source["debian_addons"],
            ],
            notify => Service["apache2"],
        }

        exec { '/usr/sbin/a2dissite default': 
            require => Package["apache2"],
        }
        file { '/etc/apache2/sites-available/radosgw':
            require => Package["apache2"],
            content => '
<VirtualHost *:80>
        ServerName ceph1.fqdn.tld
        ServerAdmin root@ceph1
        DocumentRoot /var/www

        # rewrting rules only need for amazon s3
        RewriteEngine On
        RewriteRule ^/([a-zA-Z0-9-_.]*)([/]?.*) /s3gw.fcgi?page=$1&params=$2&%{QUERY_STRING} [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]

        FastCgiExternalServer /var/www/s3gw.fcgi -socket /tmp/radosgw.sock
        <IfModule mod_fastcgi.c>
                <Directory /var/www>
                        Options +ExecCGI
                        AllowOverride All
                        SetHandler fastcgi-script
                        Order allow,deny
                        Allow from all
                        AuthBasicAuthoritative Off
                </Directory>
        </IfModule>

        AllowEncodedSlashes On
        ErrorLog /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined
        ServerSignature Off
</VirtualHost>
            '
        }
        file { '/var/www/s3gw.fcgi':
            content => '
exec /usr/bin/radosgw -c /etc/ceph/ceph.conf -n client.radosgw.gateway
',
            mode => 755,
            require => Package["apache2"],
        }

        exec {'/usr/sbin/a2enmod rewrite fastcgi':
            require => [
                Package["apache2"],
                Package["libapache2-mod-fastcgi"],
            ],
            notify => Service["apache2"],
        }

        exec {'/usr/sbin/a2ensite radosgw': 
            require => [
                Package["apache2"],
                Package["libapache2-mod-fastcgi"],
                File["/etc/apache2/sites-available/radosgw"],
            ],
            notify => Service["apache2"],
        }
        service{"apache2": 
            hasrestart => true,
        }
    } else {
        package {"radosgw": ensure => absent }
        package {"apache2": ensure => absent }
        package {"libapache2-mod-fastcgi": ensure => absent } 
    } 
}


