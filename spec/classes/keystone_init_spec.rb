require 'spec_helper'

describe 'keystone' do

  let :global_facts do
    {
      :concat_basedir => '/var/lib/puppet/concat',
      :fqdn           => 'some.host.tld'
    }
  end

  let :facts do
    @default_facts.merge(global_facts.merge({
      :osfamily               => 'Debian',
      :operatingsystem        => 'Debian',
      :operatingsystemrelease => '7.0',
      :os                     => { :name  => 'Debian', :family => 'Debian', :release => { :major => '7', :minor => '0' } },
    }))
  end

  default_params = {
      'admin_token'                        => 'service_token',
      'admin_password'                     => 'special_password',
      'package_ensure'                     => 'present',
      'client_package_ensure'              => 'present',
      'public_bind_host'                   => '0.0.0.0',
      'public_port'                        => '5000',
      'catalog_type'                       => 'sql',
      'catalog_driver'                     => false,
      'token_provider'                     => 'fernet',
      'password_hash_algorithm'            => '<SERVICE DEFAULT>',
      'password_hash_rounds'               => '<SERVICE DEFAULT>',
      'revoke_driver'                      => 'sql',
      'revoke_by_id'                       => true,
      'cache_backend'                      => '<SERVICE DEFAULT>',
      'cache_backend_argument'             => '<SERVICE DEFAULT>',
      'cache_enabled'                      => '<SERVICE DEFAULT>',
      'cache_memcache_servers'             => '<SERVICE DEFAULT>',
      'enable_ssl'                         => false,
      'ssl_certfile'                       => '/etc/keystone/ssl/certs/keystone.pem',
      'ssl_keyfile'                        => '/etc/keystone/ssl/private/keystonekey.pem',
      'ssl_ca_certs'                       => '/etc/keystone/ssl/certs/ca.pem',
      'ssl_ca_key'                         => '/etc/keystone/ssl/private/cakey.pem',
      'ssl_cert_subject'                   => '/C=US/ST=Unset/L=Unset/O=Unset/CN=localhost',
      'enabled'                            => true,
      'manage_service'                     => true,
      'default_transport_url'              => '<SERVICE DEFAULT>',
      'notification_transport_url'         => '<SERVICE DEFAULT>',
      'rabbit_heartbeat_timeout_threshold' => '<SERVICE DEFAULT>',
      'rabbit_heartbeat_rate'              => '<SERVICE DEFAULT>',
      'rabbit_heartbeat_in_pthread'        => '<SERVICE DEFAULT>',
      'amqp_durable_queues'                => '<SERVICE DEFAULT>',
      'member_role_id'                     => '<SERVICE DEFAULT>',
      'member_role_name'                   => '<SERVICE DEFAULT>',
      'sync_db'                            => true,
      'purge_config'                       => false,
      'keystone_user'                      => 'keystone',
      'keystone_group'                     => 'keystone',
  }

  override_params = {
      'package_ensure'                     => 'latest',
      'client_package_ensure'              => 'latest',
      'public_bind_host'                   => '0.0.0.0',
      'public_port'                        => '5001',
      'admin_token'                        => 'service_token_override',
      'admin_password'                     => 'admin_openstack_password',
      'catalog_type'                       => 'template',
      'token_provider'                     => 'uuid',
      'password_hash_algorithm'            => 'pbkdf2_sha512',
      'password_hash_rounds'               => '29000',
      'revoke_driver'                      => 'kvs',
      'revoke_by_id'                       => false,
      'public_endpoint'                    => 'https://localhost:5000',
      'enable_ssl'                         => true,
      'ssl_certfile'                       => '/etc/keystone/ssl/certs/keystone.pem',
      'ssl_keyfile'                        => '/etc/keystone/ssl/private/keystonekey.pem',
      'ssl_ca_certs'                       => '/etc/keystone/ssl/certs/ca.pem',
      'ssl_ca_key'                         => '/etc/keystone/ssl/private/cakey.pem',
      'ssl_cert_subject'                   => '/C=US/ST=Unset/L=Unset/O=Unset/CN=localhost',
      'enabled'                            => false,
      'manage_service'                     => true,
      'default_transport_url'              => 'rabbit://user:pass@host:1234/virt',
      'notification_transport_url'         => 'rabbit://user:pass@host:1234/virt',
      'rabbit_heartbeat_timeout_threshold' => '60',
      'rabbit_heartbeat_rate'              => '10',
      'rabbit_heartbeat_in_pthread'        => true,
      'rabbit_ha_queues'                   => true,
      'amqp_durable_queues'                => true,
      'default_domain'                     => 'other_domain',
      'member_role_id'                     => '123456789',
      'member_role_name'                   => 'othermember',
      'using_domain_config'                => false,
      'keystone_user'                      => 'test_user',
      'keystone_group'                     => 'test_group',
    }

  httpd_params = {'service_name' => 'httpd'}.merge(default_params)

  shared_examples_for 'core keystone examples' do |param_hash|
    it { is_expected.to contain_class('keystone::logging') }
    it { is_expected.to contain_class('keystone::params') }
    it { is_expected.to contain_class('keystone::policy') }

    it { is_expected.to contain_package('keystone').with(
      'ensure' => param_hash['package_ensure'],
      'tag'    => ['openstack', 'keystone-package'],
    ) }

    it { is_expected.to contain_class('keystone::client').with(
      'ensure' => param_hash['client_package_ensure'],
    ) }

    it 'should synchronize the db if $sync_db is true' do
      if param_hash['sync_db']
        is_expected.to contain_exec('keystone-manage db_sync').with(
          :command     => 'keystone-manage  db_sync',
          :user        => 'keystone',
          :refreshonly => true,
          :subscribe   => ['Anchor[keystone::install::end]',
                           'Anchor[keystone::config::end]',
                           'Anchor[keystone::dbsync::begin]'],
          :notify      => 'Anchor[keystone::dbsync::end]',
        )
      end
    end

    it 'should bootstrap $enable_bootstrap is true' do
      if param_hash['enable_bootstrap']
        is_expected.to contain_exec('keystone-manage bootstrap').with(
          :command     => 'keystone-manage bootstrap',
          :environment => 'OS_BOOTSTRAP_PASSWORD=service_password',
          :user        => param_hash['keystone_user'],
          :refreshonly => true
        )
      end
    end

    it 'passes purge to resource' do
      is_expected.to contain_resources('keystone_config').with({
        :purge => false
      })
    end

    it 'should contain correct config' do
      [
       'member_role_id',
       'member_role_name',
      ].each do |config|
        is_expected.to contain_keystone_config("DEFAULT/#{config}").with_value(param_hash[config])
      end
    end

    it 'should contain correct admin_token config' do
      is_expected.to contain_keystone_config('DEFAULT/admin_token').with_value(param_hash['admin_token']).with_secret(true)
    end

    it 'should contain correct mysql config' do
      is_expected.to contain_class('keystone::db')
    end

    it { is_expected.to contain_keystone_config('token/provider').with_value(
      param_hash['token_provider']
    ) }

    it 'should contain correct revoke driver' do
      is_expected.to contain_keystone_config('revoke/driver').with_value(param_hash['revoke_driver'])
    end

    it 'should contain password_hash_algorithm' do
      is_expected.to contain_keystone_config('identity/password_hash_algorithm').with_value(param_hash['password_hash_algorithm'])
    end

    it 'should contain password_hash_rounds' do
      is_expected.to contain_keystone_config('identity/password_hash_rounds').with_value(param_hash['password_hash_rounds'])
    end

    it 'should contain default revoke_by_id value ' do
      is_expected.to contain_keystone_config('token/revoke_by_id').with_value(param_hash['revoke_by_id'])
    end

    it 'should ensure proper setting of public_endpoint' do
      if param_hash['public_endpoint']
        is_expected.to contain_keystone_config('DEFAULT/public_endpoint').with_value(param_hash['public_endpoint'])
      else
        is_expected.to contain_keystone_config('DEFAULT/public_endpoint').with_value('http://127.0.0.1:5000')
      end
    end

    it 'should contain correct default transport url' do
      is_expected.to contain_keystone_config('DEFAULT/transport_url').with_value(params['default_transport_url'])
    end

    it 'should contain correct rabbit heartbeat configuration' do
      is_expected.to contain_keystone_config('oslo_messaging_rabbit/heartbeat_timeout_threshold').with_value(param_hash['rabbit_heartbeat_timeout_threshold'])
      is_expected.to contain_keystone_config('oslo_messaging_rabbit/heartbeat_rate').with_value(param_hash['rabbit_heartbeat_rate'])
      is_expected.to contain_keystone_config('oslo_messaging_rabbit/heartbeat_in_pthread').with_value(param_hash['rabbit_heartbeat_in_pthread'])
      is_expected.to contain_keystone_config('oslo_messaging_rabbit/amqp_durable_queues').with_value(param_hash['amqp_durable_queues'])
    end

    it 'should remove max_token_size param by default' do
      is_expected.to contain_keystone_config('DEFAULT/max_token_size').with_value('<SERVICE DEFAULT>')
    end

    it 'should ensure rabbit_ha_queues' do
      if param_hash['rabbit_ha_queues']
        is_expected.to contain_keystone_config('oslo_messaging_rabbit/rabbit_ha_queues').with_value(param_hash['rabbit_ha_queues'])
      else
        is_expected.to contain_keystone_config('oslo_messaging_rabbit/rabbit_ha_queues').with_value('<SERVICE DEFAULT>')
      end

    end

    if param_hash['default_domain']
      it { is_expected.to contain_keystone_domain(param_hash['default_domain']).with(:is_default => true) }
      it { is_expected.to contain_anchor('default_domain_created') }
    end
  end

  [default_params, override_params].each do |param_hash|
    describe "when #{param_hash == default_params ? "using default" : "specifying"} class parameters for service" do

      let :params do
        param_hash
      end

      it_configures 'core keystone examples', param_hash

      it { is_expected.to contain_service('keystone').with(
        'ensure'     => (param_hash['manage_service'] && param_hash['enabled']) ? 'running' : 'stopped',
        'enable'     => param_hash['enabled'],
        'hasstatus'  => true,
        'hasrestart' => true,
        'tag'        => 'keystone-service',
      ) }

      it { is_expected.to contain_anchor('keystone::service::end') }

    end
  end

  shared_examples_for "when using default class parameters for httpd on Debian" do
    let :params do
      httpd_params
    end

    let :pre_condition do
      'include ::keystone::wsgi::apache'
    end

    it_configures 'core keystone examples', httpd_params

    it do
      expect {
        is_expected.to contain_service(platform_parameters[:service_name]).with('ensure' => 'running')
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected that the catalogue would contain Service\[#{platform_parameters[:service_name]}\]/)
    end

    it { is_expected.to contain_exec('restart_keystone').with(
      'command' => "service #{platform_parameters[:httpd_service_name]} restart",
    ) }
  end

  shared_examples_for "when using default class parameters for httpd on RedHat" do
    let :params do
      httpd_params
    end

    let :pre_condition do
      'include ::keystone::wsgi::apache'
    end

    it_configures 'core keystone examples', httpd_params

    it do
      expect {
        is_expected.to contain_service(platform_parameters[:service_name]).with('ensure' => 'running')
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected that the catalogue would contain Service\[#{platform_parameters[:service_name]}\]/)
    end

    it { is_expected.to contain_service('httpd').with_before(/Anchor\[keystone::service::end\]/) }
    it { is_expected.to contain_exec('restart_keystone').with(
      'command' => "service #{platform_parameters[:httpd_service_name]} restart",
    ) }
  end

  describe 'when public_bind_host or public_bind_port are set' do
    describe 'when ipv6 loopback is set' do
      let :params do
        {
          :admin_token      => 'service_token',
          :public_bind_host => '::0'
        }
      end
      it { is_expected.to contain_keystone_config("DEFAULT/public_endpoint").with_value('http://[::1]:5000') }
    end

    describe 'when ipv4 address is set' do
      let :params do
        {
          :admin_token      => 'service_token',
          :public_bind_host => '192.168.0.1',
          :public_port      => '15000'
        }
      end
      it { is_expected.to contain_keystone_config("DEFAULT/public_endpoint").with_value('http://192.168.0.1:15000') }
    end

    describe 'when unenclosed ipv6 address is set' do
      let :params do
        {
          :admin_token      => 'service_token',
          :public_bind_host => '2001:db8::1'
        }
      end
      it { is_expected.to contain_keystone_config("DEFAULT/public_endpoint").with_value('http://[2001:db8::1]:5000') }
    end

    describe 'when enclosed ipv6 address is set' do
      let :params do
        {
          :admin_token      => 'service_token',
          :public_bind_host => '[2001:db8::1]'
        }
      end
      it { is_expected.to contain_keystone_config("DEFAULT/public_endpoint").with_value('http://[2001:db8::1]:5000') }
    end
  end

  describe 'when using invalid service name for keystone' do
    let (:params) { {'service_name' => 'foo'}.merge(default_params) }

    it_raises 'a Puppet::Error', /Invalid service_name/
  end

  describe 'with disabled service managing' do
    let :params do
      { :admin_token    => 'service_token',
        :manage_service => false,
        :enabled        => false }
    end

    it { is_expected.to contain_service('keystone').with(
      'ensure'     => nil,
      'enable'     => false,
      'hasstatus'  => true,
      'hasrestart' => true
    ) }
    it { is_expected.to contain_anchor('keystone::service::end') }
  end

  describe 'when configuring signing token provider' do

    describe 'when configuring as UUID' do
      let :params do
        {
          'admin_token'    => 'service_token',
          'token_provider' => 'keystone.token.providers.uuid.Provider'
        }
      end
    end

    describe 'with invalid catalog_type' do
      let :params do
        { :admin_token  => 'service_token',
          :catalog_type => 'invalid' }
      end

      it { should raise_error(Puppet::Error) }
    end

    describe 'when configuring catalog driver' do
      let :params do
        { :admin_token    => 'service_token',
          :catalog_driver => 'alien' }
      end

      it { is_expected.to contain_keystone_config('catalog/driver').with_value(params[:catalog_driver]) }
    end
  end

  describe 'when configuring token expiration' do
    let :params do
      {
        'admin_token'      => 'service_token',
        'token_expiration' => '42',
      }
    end

    it { is_expected.to contain_keystone_config("token/expiration").with_value('42') }
  end

  describe 'when not configuring token expiration' do
    let :params do
      {
        'admin_token' => 'service_token',
      }
    end

    it { is_expected.to contain_keystone_config("token/expiration").with_value('3600') }
  end

  describe 'when sync_db is set to false' do
    let :params do
      {
        'admin_token' => 'service_token',
        'sync_db'     => false,
      }
    end

    it { is_expected.not_to contain_exec('keystone-manage db_sync') }
  end

  describe 'when enable_bootstrap is set to false' do
    let :params do
      {
        'admin_token'      => 'service_token',
        'enable_bootstrap' => false,
      }
    end

    it { is_expected.not_to contain_exec('keystone-manage bootstrap') }
  end

  describe 'configure memcache servers if set' do
    let :params do
      {
        'admin_token'                  => 'service_token',
        'cache_backend'                => 'dogpile.cache.memcached',
        'cache_backend_argument'       => ['url:SERVER1:12211'],
        'cache_memcache_servers'       => 'SERVER1:11211,SERVER2:11211,[fd12:3456:789a:1::1]:11211',
        'memcache_dead_retry'          => '60',
        'memcache_socket_timeout'      => '2.0',
        'memcache_pool_maxsize'        => '1000',
        'memcache_pool_unused_timeout' => '60',
      }
    end

    it { is_expected.to contain_keystone_config('cache/enabled').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('token/caching').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/backend').with_value('dogpile.cache.memcached') }
    it { is_expected.to contain_keystone_config('cache/backend_argument').with_value('url:SERVER1:12211') }
    it { is_expected.to contain_keystone_config('memcache/dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('memcache/socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('memcache/pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('memcache/pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_servers').with_value('SERVER1:11211,SERVER2:11211,inet6:[fd12:3456:789a:1::1]:11211') }
  end

  describe 'configure cache memcache servers if set' do
    let :params do
      {
        'admin_token'                          => 'service_token',
        'cache_backend'                        => 'dogpile.cache.memcached',
        'cache_backend_argument'               => ['url:SERVER3:12211'],
        'cache_memcache_servers'               => [ 'SERVER1:11211', 'SERVER2:11211', '[fd12:3456:789a:1::1]:11211' ],
        'memcache_dead_retry'                  => '60',
        'memcache_socket_timeout'              => '2.0',
        'memcache_pool_maxsize'                => '1000',
        'memcache_pool_unused_timeout'         => '60',
        'memcache_pool_connection_get_timeout' => '30',
        'manage_backend_package'               => false,
      }
    end

    it { is_expected.to contain_keystone_config('cache/enabled').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('token/caching').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/backend').with_value('dogpile.cache.memcached') }
    it { is_expected.to contain_keystone_config('cache/backend_argument').with_value('url:SERVER3:12211') }
    it { is_expected.to contain_keystone_config('memcache/dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('memcache/socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('memcache/pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('memcache/pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_connection_get_timeout').with_value('30') }
    it { is_expected.to contain_keystone_config('cache/memcache_servers').with_value('SERVER1:11211,SERVER2:11211,inet6:[fd12:3456:789a:1::1]:11211') }
    it { is_expected.to contain_oslo__cache('keystone_config').with_manage_backend_package(false) }
  end

  describe 'configure cache enabled if set' do
    let :params do
      {
        'admin_token'                          => 'service_token',
        'cache_backend'                        => 'dogpile.cache.memcached',
        'cache_backend_argument'               => ['url:SERVER3:12211'],
        'cache_enabled'                        => true,
        'cache_memcache_servers'               => [ 'SERVER1:11211', 'SERVER2:11211', '[fd12:3456:789a:1::1]:11211' ],
        'memcache_dead_retry'                  => '60',
        'memcache_socket_timeout'              => '2.0',
        'memcache_pool_maxsize'                => '1000',
        'memcache_pool_unused_timeout'         => '60',
        'memcache_pool_connection_get_timeout' => '30',
      }
    end

    it { is_expected.to contain_keystone_config('cache/enabled').with_value(true) }
    it { is_expected.to contain_keystone_config('token/caching').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/backend').with_value('dogpile.cache.memcached') }
    it { is_expected.to contain_keystone_config('cache/backend_argument').with_value('url:SERVER3:12211') }
    it { is_expected.to contain_keystone_config('memcache/dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('memcache/socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('memcache/pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('memcache/pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_dead_retry').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_socket_timeout').with_value('2.0') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_maxsize').with_value('1000') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_unused_timeout').with_value('60') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_connection_get_timeout').with_value('30') }
    it { is_expected.to contain_keystone_config('cache/memcache_servers').with_value('SERVER1:11211,SERVER2:11211,inet6:[fd12:3456:789a:1::1]:11211') }
  end

  describe 'configure memcache servers with a string' do
    let :params do
      default_params.merge({
        'cache_memcache_servers' => 'SERVER1:11211,SERVER2:11211,[fd12:3456:789a:1::1]:11211'
      })
    end

    it { is_expected.to contain_keystone_config('cache/memcache_servers').with_value('SERVER1:11211,SERVER2:11211,inet6:[fd12:3456:789a:1::1]:11211') }
  end

  describe 'do not configure memcache servers when not set' do
    let :params do
      default_params
    end

    it { is_expected.to contain_keystone_config("cache/enabled").with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config("token/caching").with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config("cache/backend").with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config("cache/backend_argument").with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config("cache/debug_cache_backend").with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('memcache/dead_retry').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('memcache/pool_maxsize').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('memcache/pool_unused_timeout').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_dead_retry').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_socket_timeout').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_maxsize').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_unused_timeout').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_pool_connection_get_timeout').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('cache/memcache_servers').with_value('<SERVICE DEFAULT>') }
  end

  describe 'when enabling SSL' do
    let :params do
      {
        'admin_token'     => 'service_token',
        'enable_ssl'      => true,
        'public_endpoint' => 'https://localhost:5000',
      }
    end
    it {is_expected.to contain_keystone_config('ssl/enable').with_value(true)}
    it {is_expected.to contain_keystone_config('ssl/certfile').with_value('/etc/keystone/ssl/certs/keystone.pem')}
    it {is_expected.to contain_keystone_config('ssl/keyfile').with_value('/etc/keystone/ssl/private/keystonekey.pem')}
    it {is_expected.to contain_keystone_config('ssl/ca_certs').with_value('/etc/keystone/ssl/certs/ca.pem')}
    it {is_expected.to contain_keystone_config('ssl/ca_key').with_value('/etc/keystone/ssl/private/cakey.pem')}
    it {is_expected.to contain_keystone_config('ssl/cert_subject').with_value('/C=US/ST=Unset/L=Unset/O=Unset/CN=localhost')}
    it {is_expected.to contain_keystone_config('DEFAULT/public_endpoint').with_value('https://localhost:5000')}
  end

  describe 'when disabling SSL' do
    let :params do
      {
        'admin_token' => 'service_token',
        'enable_ssl'  => false,
      }
    end
    it {is_expected.to contain_keystone_config('ssl/enable').with_value(false)}
    it {is_expected.to contain_keystone_config('DEFAULT/public_endpoint').with_value('http://127.0.0.1:5000')}
  end

  describe 'not setting notification settings by default' do
    let :params do
      default_params
    end

    it { is_expected.to contain_keystone_config('oslo_messaging_notifications/transport_url').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('oslo_messaging_notifications/driver').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('oslo_messaging_notifications/topics').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('DEFAULT/notification_format').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('DEFAULT/control_exchange').with_value('<SERVICE DEFAULT>') }
    it { is_expected.to contain_keystone_config('DEFAULT/rpc_response_timeout').with_value('<SERVICE DEFAULT>') }
  end

  describe 'with RabbitMQ communication SSLed' do
    let :params do
      default_params.merge!({
        :rabbit_use_ssl     => true,
        :kombu_ssl_ca_certs => '/path/to/ssl/ca/certs',
        :kombu_ssl_certfile => '/path/to/ssl/cert/file',
        :kombu_ssl_keyfile  => '/path/to/ssl/keyfile',
        :kombu_ssl_version  => 'TLSv1'
      })
    end

    it { is_expected.to contain_oslo__messaging__rabbit('keystone_config').with(
        :rabbit_use_ssl     => true,
        :kombu_ssl_ca_certs => '/path/to/ssl/ca/certs',
        :kombu_ssl_certfile => '/path/to/ssl/cert/file',
        :kombu_ssl_keyfile  => '/path/to/ssl/keyfile',
        :kombu_ssl_version  => 'TLSv1'
    )}
  end

  describe 'with RabbitMQ communication not SSLed' do
    let :params do
      default_params.merge!({
        :rabbit_use_ssl     => '<SERVICE DEFAULT>',
        :kombu_ssl_ca_certs => '<SERVICE DEFAULT>',
        :kombu_ssl_certfile => '<SERVICE DEFAULT>',
        :kombu_ssl_keyfile  => '<SERVICE DEFAULT>',
        :kombu_ssl_version  => '<SERVICE DEFAULT>'
      })
    end

    it { is_expected.to contain_oslo__messaging__rabbit('keystone_config').with(
        :rabbit_use_ssl     => '<SERVICE DEFAULT>',
        :kombu_ssl_ca_certs => '<SERVICE DEFAULT>',
        :kombu_ssl_certfile => '<SERVICE DEFAULT>',
        :kombu_ssl_keyfile  => '<SERVICE DEFAULT>',
        :kombu_ssl_version  => '<SERVICE DEFAULT>'
    )}
  end

  describe 'when configuring max_token_size' do
    let :params do
      default_params.merge({:max_token_size => '16384' })
    end

    it { is_expected.to contain_keystone_config('DEFAULT/max_token_size').with_value(params[:max_token_size]) }
  end

  describe 'setting notification settings' do
    let :params do
      default_params.merge({
        :notification_driver  => ['keystone.openstack.common.notifier.rpc_notifier'],
        :notification_topics  => ['notifications'],
        :notification_format  => 'cadf',
        :control_exchange     => 'keystone',
        :rpc_response_timeout => '120'
      })
    end

    it { is_expected.to contain_keystone_config('oslo_messaging_notifications/driver').with_value('keystone.openstack.common.notifier.rpc_notifier') }
    it { is_expected.to contain_keystone_config('oslo_messaging_notifications/topics').with_value('notifications') }
    it { is_expected.to contain_keystone_config('DEFAULT/notification_format').with_value('cadf') }
    it { is_expected.to contain_keystone_config('DEFAULT/control_exchange').with_value('keystone') }
    it { is_expected.to contain_keystone_config('DEFAULT/rpc_response_timeout').with_value('120') }
  end

  describe 'setting kombu settings' do
    let :params do
      default_params.merge({
        :kombu_reconnect_delay => '1.0',
        :kombu_compression     => 'gzip',
      })
    end

    it { is_expected.to contain_keystone_config('oslo_messaging_rabbit/kombu_reconnect_delay').with_value('1.0') }
    it { is_expected.to contain_keystone_config('oslo_messaging_rabbit/kombu_compression').with_value('gzip') }
    it { is_expected.to contain_keystone_config('oslo_messaging_rabbit/kombu_failover_strategy').with_value('<SERVICE DEFAULT>') }
  end

  describe 'setting enable_proxy_headers_parsing' do
    let :params do
      default_params.merge({:enable_proxy_headers_parsing => true })
    end

    it { is_expected.to contain_oslo__middleware('keystone_config').with(
      :enable_proxy_headers_parsing => true,
    )}
  end

  describe 'setting max_request_body_size' do
    let :params do
      default_params.merge({:max_request_body_size => '1146880' })
    end

    it { is_expected.to contain_oslo__middleware('keystone_config').with(
      :max_request_body_size => '1146880',
    )}
  end

  describe 'setting sql policy driver' do
    let :params do
      default_params.merge({:policy_driver => 'sql' })
    end

    it { is_expected.to contain_keystone_config('policy/driver').with_value('sql') }
  end

  describe 'setting sql (default) catalog' do
    let :params do
      default_params
    end

    it { is_expected.to contain_keystone_config('catalog/driver').with_value('sql') }
  end

  describe 'setting default template catalog' do
    let :params do
      {
        :admin_token  => 'service_token',
        :catalog_type => 'template'
      }
    end

    it { is_expected.to contain_keystone_config('catalog/driver').with_value('templated') }
    it { is_expected.to contain_keystone_config('catalog/template_file').with_value('/etc/keystone/default_catalog.templates') }
  end

  describe 'with overridden validation_auth_url' do
    let :params do
      {
        :admin_token       => 'service_token',
        :validate_service  => true,
        :validate_auth_url => 'http://some.host:5000',
        :admin_endpoint    => 'http://some.host:5000'
      }
    end

    it { is_expected.to contain_class('keystone::service').with(
      'validate'       => true,
      'admin_endpoint' => 'http://some.host:5000'
    )}
  end

  describe 'with service validation' do
    let :params do
      {
        :admin_token      => 'service_token',
        :validate_service => true,
        :admin_endpoint   => 'http://some.host:5000'
      }
    end

    it { is_expected.to contain_class('keystone::service').with(
      'validate'       => true,
      'admin_endpoint' => 'http://some.host:5000'
    )}
  end

  describe 'setting another template catalog' do
    let :params do
      {
        :admin_token           => 'service_token',
        :catalog_type          => 'template',
        :catalog_template_file => '/some/template_file'
      }
    end

    it { is_expected.to contain_keystone_config('catalog/driver').with_value('templated') }
    it { is_expected.to contain_keystone_config('catalog/template_file').with_value('/some/template_file') }
  end

  describe 'when using credentials' do
    describe 'when enabling credential_setup' do
      let :params do
        default_params.merge({
          'enable_credential_setup'   => true,
          'credential_key_repository' => '/etc/keystone/credential-keys',
        })
      end
      it { is_expected.to contain_file(params['credential_key_repository']).with(
        :ensure => 'directory',
        :owner  => params['keystone_user'],
        :group  => params['keystone_group'],
        'mode'  => '0600',
      ) }

      it { is_expected.to contain_exec('keystone-manage credential_setup').with(
        :command => "keystone-manage credential_setup --keystone-user #{params['keystone_user']} --keystone-group #{params['keystone_group']}",
        :user    => params['keystone_user'],
        :creates => '/etc/keystone/credential-keys/0',
        :require => 'File[/etc/keystone/credential-keys]',
      ) }
      it { is_expected.to contain_keystone_config('credential/key_repository').with_value('/etc/keystone/credential-keys')}
    end

    describe 'when overriding the credential key directory' do
      let :params do
        default_params.merge({
          'enable_credential_setup'   => true,
          'credential_key_repository' => '/var/lib/credential-keys',
        })
      end
      it { is_expected.to contain_exec('keystone-manage credential_setup').with(
        :creates => '/var/lib/credential-keys/0'
      ) }
    end

    describe 'when overriding the keystone group and user' do
      let :params do
        default_params.merge({
          'enable_credential_setup' => true,
          'keystone_user'           => 'test_user',
          'keystone_group'          => 'test_group',
        })
      end

      it { is_expected.to contain_exec('keystone-manage credential_setup').with(
        :command => "keystone-manage credential_setup --keystone-user #{params['keystone_user']} --keystone-group #{params['keystone_group']}",
        :user    => params['keystone_user'],
        :creates => '/etc/keystone/credential-keys/0',
        :require => 'File[/etc/keystone/credential-keys]',
      ) }
    end

    describe 'when setting credential_keys parameter' do
      let :params do
        default_params.merge({
          'enable_credential_setup' => true,
          'credential_keys' => {
            '/etc/keystone/credential-keys/0' => {
              'content' => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
            },
            '/etc/keystone/credential-keys/1' => {
              'content' => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
            },
          }
        })
      end

      it { is_expected.to_not contain_exec('keystone-manage credential_setup') }
      it { is_expected.to contain_file('/etc/keystone/credential-keys/0').with(
        'content'   => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
        'owner'     => 'keystone',
        'subscribe' => 'Anchor[keystone::install::end]',
      )}
      it { is_expected.to contain_file('/etc/keystone/credential-keys/1').with(
        'content'   => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
        'owner'     => 'keystone',
        'subscribe' => 'Anchor[keystone::install::end]',
      )}
    end

    describe 'when disabling credential_setup' do
      let :params do
        default_params.merge({
          'enable_credential_setup'   => false,
          'credential_key_repository' => '/etc/keystone/credential-keys',
        })
      end
      it { is_expected.to_not contain_file(params['credential_key_repository']) }
      it { is_expected.to_not contain_exec('keystone-manage credential_setup') }
    end
  end

  describe 'when using fernet tokens' do
    describe 'when enabling fernet_setup' do
      let :params do
        default_params.merge({
          'enable_fernet_setup'    => true,
          'fernet_max_active_keys' => 5,
          'revoke_by_id'           => false,
          'fernet_key_repository'  => '/etc/keystone/fernet-keys',
        })
      end

      it { is_expected.to contain_file(params['fernet_key_repository']).with(
        :ensure => 'directory',
        :owner  => params['keystone_user'],
        :group  => params['keystone_group'],
        :mode   => '0600',
      ) }

      it { is_expected.to contain_exec('keystone-manage fernet_setup').with(
        :command => "keystone-manage fernet_setup --keystone-user #{params['keystone_user']} --keystone-group #{params['keystone_group']}",
        :user    => params['keystone_user'],
        :creates => '/etc/keystone/fernet-keys/0',
        :require => 'File[/etc/keystone/fernet-keys]',
      ) }
      it { is_expected.to contain_keystone_config('fernet_tokens/max_active_keys').with_value(5)}
      it { is_expected.to contain_keystone_config('token/revoke_by_id').with_value(false)}
    end

    describe 'when overriding the fernet key directory' do
      let :params do
        default_params.merge({
          'enable_fernet_setup'   => true,
          'fernet_key_repository' => '/var/lib/fernet-keys',
        })
      end
      it { is_expected.to contain_exec('keystone-manage fernet_setup').with(
        :creates => '/var/lib/fernet-keys/0'
      ) }

    end

    describe 'when overriding the keystone group and user' do
      let :params do
        default_params.merge({
          'enable_fernet_setup'   => true,
          'fernet_key_repository' => '/etc/keystone/fernet-keys',
          'keystone_user'         => 'test_user',
          'keystone_group'        => 'test_group',
        })
      end

      it { is_expected.to contain_exec('keystone-manage fernet_setup').with(
        :command => "keystone-manage fernet_setup --keystone-user #{params['keystone_user']} --keystone-group #{params['keystone_group']}",
        :user    => params['keystone_user'],
        :creates => '/etc/keystone/fernet-keys/0',
        :require => 'File[/etc/keystone/fernet-keys]',
      ) }

    end
  end

  describe 'when setting fernet_keys parameter' do
    let :params do
      default_params.merge({
        'enable_fernet_setup' => true,
        'fernet_keys' => {
          '/etc/keystone/fernet-keys/0' => {
            'content' => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
          },
          '/etc/keystone/fernet-keys/1' => {
            'content' => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
          },
        }
      })
    end

    it { is_expected.to_not contain_exec('keystone-manage fernet_setup') }
    it { is_expected.to contain_file('/etc/keystone/fernet-keys/0').with(
      'content'   => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
      'owner'     => 'keystone',
      'mode'      => '0600',
      'replace'   => true,
      'subscribe' => 'Anchor[keystone::install::end]',
    )}
    it { is_expected.to contain_file('/etc/keystone/fernet-keys/1').with(
      'content'   => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
      'owner'     => 'keystone',
      'mode'      => '0600',
      'replace'   => true,
      'subscribe' => 'Anchor[keystone::install::end]',
    )}
  end

  describe 'when not replacing fernet_keys and setting fernet_keys parameter' do
    let :params do
      default_params.merge({
        'enable_fernet_setup' => true,
        'fernet_keys' => {
          '/etc/keystone/fernet-keys/0' => {
            'content' => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
          },
          '/etc/keystone/fernet-keys/1' => {
            'content' => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
          },
        },
        'fernet_replace_keys' => false,
      })
    end

    it { is_expected.to_not contain_exec('keystone-manage fernet_setup') }
    it { is_expected.to contain_file('/etc/keystone/fernet-keys/0').with(
      'content'   => 't-WdduhORSqoyAykuqWAQSYjg2rSRuJYySgI2xh48CI=',
      'owner'     => 'keystone',
      'mode'      => '0600',
      'replace'   => false,
      'subscribe' => 'Anchor[keystone::install::end]',
    )}
    it { is_expected.to contain_file('/etc/keystone/fernet-keys/1').with(
      'content'   => 'GLlnyygEVJP4-H2OMwClXn3sdSQUZsM5F194139Unv8=',
      'owner'     => 'keystone',
      'mode'      => '0600',
      'replace'   => false,
      'subscribe' => 'Anchor[keystone::install::end]',
    )}
  end

  shared_examples_for "when configuring default domain" do
    describe 'with default domain and eventlet service is managed and enabled' do
      let :params do
        default_params.merge({
          'default_domain'=> 'test',
        })
      end
      it { is_expected.to contain_exec('restart_keystone').with(
        'command' => "service #{platform_parameters[:service_name]} restart",
      ) }
      it { is_expected.to contain_anchor('default_domain_created') }
    end
    describe 'with default domain and wsgi service is managed and enabled' do
      let :pre_condition do
        'include ::apache'
      end
      let :params do
        default_params.merge({
          'default_domain'=> 'test',
          'service_name'  => 'httpd',
        })
      end
      it { is_expected.to contain_anchor('default_domain_created') }
    end
    describe 'with default domain and service is not managed' do
      let :params do
        default_params.merge({
          'default_domain' => 'test',
          'manage_service' => false,
        })
      end
      it { is_expected.to_not contain_exec('restart_keystone') }
      it { is_expected.to contain_anchor('default_domain_created') }
    end
  end

  context 'on RedHat platforms' do
    let :facts do
      @default_facts.merge(global_facts.merge({
        :osfamily               => 'RedHat',
        :operatingsystem        => 'RedHat',
        :operatingsystemrelease => '7.0',
        :os                     => { :name  => 'RedHat', :family => 'RedHat', :release => { :major => '7', :minor => '0' } },
      }))
    end

    let :platform_parameters do
      {
        :service_name       => 'openstack-keystone',
        :httpd_service_name => 'httpd',
      }
    end

    it_configures 'when using default class parameters for httpd on RedHat'
    it_configures 'when configuring default domain'
  end

  context 'on Debian platforms' do
    let :facts do
      @default_facts.merge(global_facts.merge({
        :osfamily               => 'Debian',
        :operatingsystem        => 'Debian',
        :operatingsystemrelease => '7.0',
        :os                     => { :name  => 'Debian', :family => 'Debian', :release => { :major => '7', :minor => '0' } },
      }))
    end

    let :platform_parameters do
      {
        :service_name       => 'keystone',
        :httpd_service_name => 'apache2',
      }
    end

    it_configures 'when using default class parameters for httpd on Debian'
    it_configures 'when configuring default domain'
  end

  describe "when configuring using_domain_config" do
    describe 'with default config' do
      let :params do
        default_params
      end
      it { is_expected.to_not contain_file('/etc/keystone/domains') }
    end
    describe 'when using domain config' do
      let :params do
        default_params.merge({
          'using_domain_config'=> true,
        })
      end
      it { is_expected.to contain_file('/etc/keystone/domains').with(
        'ensure' => "directory",
      ) }
      it { is_expected
          .to contain_keystone_config('identity/domain_specific_drivers_enabled')
          .with('value' => true,
      ) }
      it { is_expected
          .to contain_keystone_config('identity/domain_config_dir')
          .with('value' => '/etc/keystone/domains',
      ) }
    end
    describe 'when using domain config and a wrong directory' do
      let :params do
        default_params.merge({
          'using_domain_config'=> true,
          'domain_config_directory' => 'this/is/not/an/absolute/path'
        })
      end

      it { should raise_error(Puppet::Error) }
    end
    describe 'when setting domain directory and not using domain config' do
      let :params do
        default_params.merge({
          'using_domain_config'=> false,
          'domain_config_directory' => '/this/is/an/absolute/path'
        })
      end
      it 'should raise an error' do
        expect { should contain_file('/etc/keystone/domains') }
          .to raise_error(Puppet::Error, %r(You must activate domain))
      end
    end
    describe 'when setting domain directory and using domain config' do
      let :params do
        default_params.merge({
          'using_domain_config'=> true,
          'domain_config_directory' => '/this/is/an/absolute/path'
        })
      end
      it { is_expected.to contain_file('/this/is/an/absolute/path').with(
        'ensure' => "directory",
      ) }
    end
  end
end
