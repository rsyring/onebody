namespace :deploy do

  task :before_setup do
    sudo "mkdir -p #{deploy_to}"
    sudo "chown #{user}:#{user} #{deploy_to}"
  end
  
  namespace :shared do
  
    desc 'Setup shared directories'
    task :setup do
      Dir[File.dirname(__FILE__) + '/../../db/**/*'].each do |path|
        next if path =~ /migrate/
        next unless File.directory?(path)
        run "mkdir -p #{shared_path}/db/#{path.split('db/').last}"
      end
      run "mkdir -p #{shared_path}/config"
      run "mkdir -p #{shared_path}/public"
      run "mkdir -p #{shared_path}/themes"
      run "mkdir -p #{shared_path}/plugins"
      run "mkdir -p #{shared_path}/initializers"
    end
    after 'deploy:setup', 'deploy:shared:setup'
    
  end
  
  task :create_database do
    mysql_root_password = HighLine.new.ask('MySQL ROOT password: ') { |q| q.echo = false }
    run "mysql -uroot -p#{mysql_root_password} -e \"create database onebody; grant all on onebody.* to onebody@localhost identified by '#{get_db_password}'\""
    yml = render_erb_template(File.dirname(__FILE__) + '/templates/database.yml')
    put yml, "#{shared_path}/config/database.yml"
  end
  after 'deploy:setup', 'deploy:create_database'
  
  task :after_update_code do
    rb = render_erb_template(File.dirname(__FILE__) + '/templates/links.rb')
    put rb, "#{release_path}/config/initializers/links.rb"
    commands = [
      "ln -sf #{shared_path}/config/database.yml #{release_path}/config/database.yml",
      "if [ -e #{shared_path}/config/email.yml ]; then ln -sf #{shared_path}/config/email.yml #{release_path}/config/email.yml; fi",
      "rm -rf #{release_path}/public/assets && ln -s #{shared_path}/public/assets #{release_path}/public/assets",
      "cd #{shared_path}/plugins; if [ \"$(ls -A)\" ]; then rsync -a * #{release_path}/plugins/; fi",
      "cd #{shared_path}/initializers; if [ \"$(ls -A)\" ]; then rsync -a * #{release_path}/config/initializers/; fi",
      "cd #{release_path} && whenever -w RAILS_ENV=production"
    ]
    run commands.join('; ')
  end
  
  task :copy_ssh_key do
    run "mkdir -p ~/.ssh"
    pubkey = File.read(ENV['HOME'] + '/.ssh/id_rsa.pub')
    run "echo #{pubkey} >> ~/.ssh/authorized_keys"
  end
  
end
