class profile::it::puppet_master {
	file{ '/root/README':
		ensure => file,
		content => "Welcome to ${fqdn}, this is a Puppet Master Server\n",
	}
	
	package{"puppetserver":
		ensure => installed,
		source => 'https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm',
	}

	service{"puppetserver":
		ensure => running,
		enable => true
	}
	
	file{"/etc/puppetlabs/puppet/puppet.conf":
		ensure => present,
	}
	
	ini_setting { "Puppet master Alternative DNS names":
		ensure  => present,
		path    => '/etc/puppetlabs/puppet/puppet.conf',
		section => 'master',
		setting => 'dns_alt_names',
		value   => lookup("dns_alt_names"),
	}

	ini_setting { "Puppet master certname":
		ensure  => present,
		path    => '/etc/puppetlabs/puppet/puppet.conf',
		section => 'master',
		setting => 'certname',
		value   => lookup("puppet_master_certname"),
	}

	file{'/etc/puppetlabs/puppet/autosign.conf':
		ensure => present
	}

	$autosign_domain_list = lookup("autosign_servers")
	
	$autosign_domain_list.each | $domain | {

		file_line { "Ensure ${$domain} in autosign.conf":
			ensure => present,
			path  => '/etc/puppetlabs/puppet/autosign.conf',
			line => "*.${domain}",
			match => "${domain}",
			require => File['/etc/puppetlabs/puppet/autosign.conf']
		}

	}

	file{ "/etc/hosts":
		ensure => present,
		content => "${ipaddress}\t${fqdn}",
	}
	
	file_line{"update_path_root":
		ensure => present,
		line => 'PATH=$PATH:/opt/puppetlabs/puppet/bin:$HOME/bin',
		match => "^PATH=*",
		path => "/root/.bash_profile",
	}

	exec{"install R10K":
		command => "/opt/puppetlabs/puppet/bin/gem install r10k",
		onlyif => "/usr/bin/test ! -x /opt/puppetlabs/puppet/bin/r10k"
	}
	
	file{"/etc/puppetlabs/r10k/":
		ensure => directory,
	}
	
	$hiera_id_rsa_path = lookup("hiera_repo_id_path")
	
	file{"/etc/puppetlabs/r10k/r10k.yaml":
		ensure => file,
		require => File["/etc/puppetlabs/r10k"],
		content => epp('profile/it/r10k.epp',
			{ 
				'r10k_org' => lookup("r10k_org"),
				'controlRepo' => lookup("control_repo") ,
				'r10k_hiera_org' => lookup("r10k_hiera_org") ,
				'hieraRepo' => lookup("hiera_repo"),
				'idRsaPath' => $hiera_id_rsa_path
			}
		)
	}
	
	if $hiera_id_rsa_path =~ /(.*\/)(.*\id_rsa)/ { 
		$base_path = $1
		$dir = split($base_path, "/")
		$filename = $2

		$aux_dir = [""]
		$dir.each | $index, $sub_dir | {
		
			if join( $dir[ 1,$index] , "/" ) == "" {
 				$aux_dir = "/"
 			}else{
 				$aux_dir = join( $aux_dir + $dir[1, $index] , "/")
			}
			file{ $aux_dir:
				ensure => directory,
			}
		}
		file{ $hiera_id_rsa_path:
			ensure => file,
			content => lookup("hiera_repo_id_rsa"),
			require => File[$base_path],
			mode => "600",
		}
		
	}else{
		notify { $hiera_id_rsa_path:
			message => "Hiera ID RSA isn't a full path!, path received was: ${hiera_id_rsa_path}",
		}
	}
	
	firewalld::custom_service{'puppet':
		short => 'puppet',
		description => 'Puppet Client access Puppet Server',
		port => [
				{
					'port'     => '8140',
					'protocol' => 'tcp',
				},
				{
					'port'     => '8140',
					'protocol' => 'udp',
				},
			],
	}
	
	firewalld_service { 'Allow puppet port on this server':
		ensure  => 'present',
		service => 'puppet',
	}
}
