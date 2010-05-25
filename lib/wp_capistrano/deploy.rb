require 'wp_config'
require 'erb'
require 'digest'
require 'digest/sha1'

require 'wp_capistrano/namespace/deploy'
require 'wp_capistrano/namespace/setup'
require 'wp_capistrano/namespace/wp'

Capistrano::Configuration.instance.load do
  default_run_options[:pty] = true

  def set_target target
    tt = WPConfig.instance.h['deploy'][target]
    if tt
      t = OpenStruct.new(tt)
      set :domain, t.ssh_domain
      set :user, t.ssh_user
      set :deploy_to, t.path
      set :wordpress_domain, t.vhost
      set :wordpress_db_name, t.database.name
      set :wordpress_db_user, t.database.user
      set :wordpress_db_password, t.database.password
      set :wordpress_db_host, t.database.host
      set :use_sudo, t.use_sudo

      @roles = {}
      role :app, domain
      role :web, domain
      role :db,  domain, :primary => true
    end
  end

  WPConfig.instance.h['deploy'].each_pair do |k,v|
    set_target k if v['default']
  end

  task :testing do
    set_target 'testing'
  end
  task :staging do
    set_target 'staging'
  end
  task :production do
    set_target 'production'
  end

  # Load from config
  set :wordpress_version, WPConfig.wordpress.version
  set :wordpress_git_url, WPConfig.wordpress.repository
  set :repository, WPConfig.application.repository

  # Everything else
  set :scm, "git"
  set :deploy_via, :remote_cache
  set :branch, "master"
  set :git_shallow_clone, 1
  set :git_enable_submodules, 1
  set :wordpress_db_host, "localhost"
  set :wordpress_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_secure_auth_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_logged_in_key, Digest::SHA1.hexdigest(rand.to_s)
  set :wordpress_nonce_key, Digest::SHA1.hexdigest(rand.to_s)

  #allow deploys w/o having git installed locally
  set(:real_revision) do
    output = ""
    invoke_command("git ls-remote #{repository} #{branch} | cut -f 1", :once => true) do |ch, stream, data|
      case stream
      when :out
        if data =~ /\(yes\/no\)\?/ # first time connecting via ssh, add to known_hosts?
          ch.send_data "yes\n"
        elsif data =~ /Warning/
        elsif data =~ /yes/
          #
        else
          output << data
        end
      when :err then warn "[err :: #{ch[:server]}] #{data}"
      end
    end
    output.gsub(/\\/, '').chomp
  end

  #no need for log and pids directory
  set :shared_children, %w(system)

end
