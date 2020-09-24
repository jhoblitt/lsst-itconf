# @summary
#   Icinga agent creation for metric collections

class profile::icinga::agent(
  String $icinga_master_fqdn,
  String $icinga_master_ip,
  String $credentials_hash,
  String $host_template,
  String $ca_salt,
  String $ssh_port = '22',
){
  #<-----------------------Variables-Definition--------------------------->
  $packages = [
    'nagios-plugins-all',
  ]
  $icinga_agent_fqdn = $facts['networking']['fqdn']
  $icinga_agent_ip = $facts['networking']['ip']
  $credentials = "Authorization:Basic ${credentials_hash}"
  $icinga_path = '/opt/icinga'
  $path = "${icinga_path}/${icinga_agent_fqdn}.json"
  $url = "https://${icinga_master_fqdn}/director/host"
  $cmd = "curl -s -k -H '${credentials}' -H 'Accept: application/json' -X POST '${url}' -d @${path}"
  $cond = "curl -s -k -H '${credentials}' -H 'Accept: application/json' -X GET '${url}/host?name=${icinga_agent_fqdn}' | grep Failed"
  #<-------------------End-Variables-Definition--------------------------->
  #
  #
  #<-------------------------Icinga-Configuration------------------------->
  class { '::icinga2':
    manage_repo => true,
    confd       => false,
    features    => ['mainlog'],
  }
  ##Icinga2 feature API config
  class { '::icinga2::feature::api':
    ensure          => 'present',
    ca_host         => $icinga_master_ip,
    ticket_salt     => $ca_salt,
    accept_config   => true,
    accept_commands => true,
    endpoints       => {
      $icinga_agent_fqdn  => {
        'host'  =>  $icinga_agent_ip
      },
      $icinga_master_fqdn => {
        'host'  =>  $icinga_master_ip,
      },
    },
    zones           => {
      $icinga_agent_fqdn => {
        'endpoints' => [$icinga_agent_fqdn],
        'parent'    => 'master',
      },
      'master'           => {
        'endpoints' => [$icinga_master_fqdn],
      },
    }
  }
  #<--------------------End-Icinga-Configuration-------------------------->
  #
  #
  #<----------------------Plugins-modifications--------------------------->
  file { '/usr/lib64/nagios/plugins/check_disk':
    owner   => 'root',
    group   => 'root',
    mode    => '4755',
    require => Package[$packages],
  }
  #<------------------END-Plugins-modifications--------------------------->
  #
  #
  #<-------------------------Additional-Plugins--------------------------->
  archive {'/usr/lib64/nagios/plugins/check_netio':
    ensure => present,
    source => 'https://www.claudiokuenzler.com/monitoring-plugins/check_netio.sh',
  }
  ->file { '/usr/lib64/nagios/plugins/check_netio':
    owner => 'root',
    group => 'icinga',
    mode  => '4755',
  }
  archive {'/usr/lib64/nagios/plugins/check_mem':
    ensure => present,
    source => 'https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_mem/check_mem.pl',
  }
  ->file { '/usr/lib64/nagios/plugins/check_mem':
    owner => 'root',
    group => 'icinga',
    mode  => '4755',
  }
  #<---------------------END-Additional-Plugins--------------------------->
  #
  #
  #<----------------------Add-Host-to-Icinga-Master----------------------->
  ##Create a directory to allocate json files
  file { $icinga_path:
    ensure => 'directory',
  }
  ## Create host file
  file { $path:
    ensure  => 'present',
    content => @("CONTENT"/L)
      {
      "address": "${icinga_agent_ip}",
      "display_name": "${icinga_agent_fqdn}",
      "imports": [
        "${host_template}"
      ],
      "object_name":"${icinga_agent_fqdn}",
      "object_type": "object",
      "vars": {
          "safed_profile": "3",
          "ssh_port": "${ssh_port}"
      }
      }
      | CONTENT
  }
  -> exec { $cmd:
    cwd      => $icinga_path,
    path     => ['/sbin', '/usr/sbin', '/bin'],
    provider => shell,
    onlyif   => $cond,
    loglevel => debug,
  }
  ##Add require packages
  package { $packages:
    ensure => 'present',
  }
  #<------------------End-Add-Host-to-Icinga-Master----------------------->
}


