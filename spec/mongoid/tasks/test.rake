namespace :mongoid do

  desc "Creates a test rails app for the specs to run against"
  task :setup, :parallel do |t, args|
    require 'rails/version'
    if File.exists? dir = "spec/mongoid/rails/rails-#{Rails::VERSION::STRING}"
      puts "test app #{dir} already exists; skipping"
    else
      system("mkdir spec/mongoid/rails") unless File.exists?("spec/mongoid/rails")
      system "#{'INSTALL_PARALLEL=yes' if args[:parallel]} bundle exec rails new #{dir} -m spec/mongoid/support/rails_template.rb --skip-bundle --skip-active-record"
      Rake::Task['parallel:after_setup_hook'].invoke if args[:parallel]
    end
  end

end
