require 'bundler/capistrano'

##
## updates the crontap on deploy if needed.
##
set :whenever_command, 'bundle exec whenever -f config/misc/schedule.rb'
require 'whenever/capistrano'

##
## REMEMBER: you can see available tasks with "cap -T"
##

##
## Items to configure
##

set :application, 'crabgrass'
set :user, 'crabgrass'

set :repository, 'git://0xacab.org/riseuplabs/crabgrass.git'
set :branch, 'develop'

deploy_host = ''
staging_host = 'we.dev.riseup.net'

staging = ENV['TARGET'] != 'production'

set :app_db_host, 'localhost'
set :app_db_user, 'crabgrass'
set :app_db_pass, ''

set :secret, ''

##
## Items you should probably leave alone
##

set :scm, 'git'
set :local_repository, "#{File.dirname(__FILE__)}/../"

set :deploy_via, :remote_cache

set :bundle_without, %w[development test ci].join(' ')

# asset pipeline precompilation
load 'deploy/assets'

set :assets_prefix, 'static'
set :shared_assets_prefix, 'static'

# as an alternative, if you server does NOT have direct git access to the,
# you can deploy_via :copy, which will build a tarball locally and upload
# it to the deploy server.

# set :deploy_via, :copy
set :copy_strategy, :checkout
set :copy_exclude, ['.git']

set :git_shallow_clone, 1 # only copy the most recent, not the entire repository (default:1)
set :git_enable_submodules, 0
set :keep_releases, 3

ssh_options[:paranoid] = false
ssh_options[:port] = 4422

set :use_sudo, false

role :web, (staging ? staging_host : deploy_host)
role :app, (staging ? staging_host : deploy_host)
role :db, (staging ? staging_host : deploy_host), primary: true

set :deploy_to, "/usr/apps/#{application}"

set :public_children, %w[images static]

##
## CUSTOM TASKS
##

namespace :passenger do
  desc 'Restart rails application'
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end

  # requires root
  desc 'Check memory stats'
  task :memory do
    sudo 'passenger-memory-stats'
  end

  # requires root
  desc 'Check status of rails processes'
  task :status do
    sudo 'passenger-status'
  end
end

# CREATING DATABASE.YML
# inspired by http://www.jvoorhis.com/articles/2006/07/07/managing-database-yml-with-capistrano

def database_configuration(db_role)
  %(
  production:
    database: #{application}
    adapter: mysql2
    encoding: utf8
    host: #{eval(db_role + '_db_host')}
    username: #{eval(db_role + '_db_user')}
    password: #{eval(db_role + '_db_pass')}
  )
end

namespace :crabgrass do
  # rerun after_setup if you change the db configuration
  desc 'Create shared directories, update database.yml'
  task :create_shared, roles: :app do
    run "mkdir -p #{deploy_to}/#{shared_dir}/tmp/sessions"
    run "mkdir -p #{deploy_to}/#{shared_dir}/tmp/cache"
    run "mkdir -p #{deploy_to}/#{shared_dir}/tmp/sockets"
    run "mkdir -p #{deploy_to}/#{shared_dir}/avatars"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets"
    run "mkdir -p #{deploy_to}/#{shared_dir}/index"
    run "mkdir -p #{deploy_to}/#{shared_dir}/public_assets"
    run "mkdir -p #{deploy_to}/#{shared_dir}/latex"
    run "mkdir -p #{deploy_to}/#{shared_dir}/sphinx"

    run "mkdir -p #{deploy_to}/#{shared_dir}/config/crabgrass"
    put database_configuration('app'), "#{deploy_to}/#{shared_dir}/config/database.yml"
    put secret, "#{deploy_to}/#{shared_dir}/config/crabgrass/secret.txt"
  end

  desc 'Link in the shared dirs'
  task :link_to_shared do
    run "rm -rf #{current_release}/tmp"
    run "ln -nfs #{shared_path}/tmp #{current_release}/tmp"

    run "rm -rf #{current_release}/index"
    run "ln -nfs #{shared_path}/index #{current_release}/index"

    run "rm -rf #{current_release}/assets"
    run "ln -nfs #{shared_path}/assets #{current_release}/assets"

    run "rm -rf #{current_release}/public/assets"
    run "ln -nfs #{shared_path}/public_assets #{current_release}/public/assets"

    run "rm -rf #{current_release}/public/avatars"
    run "ln -nfs #{shared_path}/avatars #{current_release}/public/avatars"

    run "rm -rf #{current_release}/public/latex"
    run "ln -nfs #{shared_path}/latex #{current_release}/public/latex"

    run "ln -nfs #{deploy_to}/#{shared_dir}/config/database.yml #{current_release}/config/database.yml"
    run "ln -nfs #{deploy_to}/#{shared_dir}/config/crabgrass/secret.txt #{current_release}/config/crabgrass/secret.txt"
    run "ln -nfs #{deploy_to}/#{shared_dir}/config/crabgrass/crabgrass.production.yml #{current_release}/config/crabgrass/crabgrass.production.yml"
    run "test -f #{deploy_to}/#{shared_dir}/config/.htpasswd && ln -nfs #{deploy_to}/#{shared_dir}/config/.htpasswd #{current_release}/config/.htpasswd"

    run "rm -rf #{current_release}/db/sphinx"
    run "ln -nfs #{shared_path}/sphinx #{current_release}/db/sphinx"
  end

  desc 'Write the VERSION file to the server'
  task :create_version_files do
    version = `git describe --tags --abbrev=0`.chomp
    run "echo #{version} > #{current_release}/VERSION"

    timestamp = current_release.scan(/\d{10,}/).first
    run "echo #{timestamp} > #{current_release}/RELEASE" if timestamp
  end

  #  desc "refresh the staging database"
  #  task :refresh do
  #    run "touch #{deploy_to}/shared/tmp/refresh.txt"
  #  end

  desc 'starts the crabgrass daemons'
  task :restart do
    run "#{deploy_to}/current/script/start_stop_crabgrass_daemons.rb restart"
  end

  desc 'get the status of the crabgrass daemons'
  task :status do
    run "#{deploy_to}/current/script/start_stop_crabgrass_daemons.rb status"
  end

  desc 'reindex sphinx'
  task :index do
    run "cd #{deploy_to}/current; rake ts:index RAILS_ENV=production"
  end

  #
  #  UPGRADE
  #
  desc 'Upgrade to Version 0.6'
  task :upgrade_to_0_6 do
    run "cd #{current_release}; RAILS_ENV=production bundle exec rake cg:upgrade:init_group_permissions cg:upgrade:migrate_group_permissions cg:upgrade:user_permissions"
  end

  desc 'Cleanup old data records that have invalid associations'
  task :cleanup_outdated_data do
    run "cd #{current_release}; RAILS_ENV=production bundle exec rake cg:cleanup:remove_dead_participations cg:cleanup:remove_dead_federatings"
  end
end

after 'deploy:setup', 'crabgrass:create_shared'

before 'deploy:finalize_update', 'crabgrass:link_to_shared'

after  'deploy:create_symlink', 'crabgrass:create_version_files'
after  'deploy:restart', 'passenger:restart', 'deploy:cleanup'

before 'deploy', 'crabgrass:cleanup_outdated_data', 'deploy:migrate'
