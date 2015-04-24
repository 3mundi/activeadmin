require 'pathname'

current_dir = Pathname.new(File.expand_path('..', __FILE__))
spec_dir = current_dir.parent.parent

# Rails template to build the sample app for specs

run "rm Gemfile"
run "rm -r test"

# Create a cucumber database and environment
copy_file spec_dir.join('support/templates/cucumber.rb'),                "config/environments/cucumber.rb"
copy_file spec_dir.join('support/templates/cucumber_with_reloading.rb'), "config/environments/cucumber_with_reloading.rb"

copy_file current_dir.join('templates/mongoid.yml'), "config/mongoid.yml"

if File.exists? 'config/secrets.yml'
  gsub_file 'config/secrets.yml', /\z/, "\ncucumber:\n  secret_key_base: #{'o' * 128}"
  gsub_file 'config/secrets.yml', /\z/, "\ncucumber_with_reloading:\n  secret_key_base: #{'o' * 128}"
end

generate :model, "post title:string body:text position:integer starred:boolean foo_id:integer"
inject_into_file 'app/models/post.rb', %q{
  include Mongoid::Timestamps
  belongs_to :category
  belongs_to :author, class_name: 'User', inverse_of: 'posts'
  has_many :taggings
  accepts_nested_attributes_for :author
  accepts_nested_attributes_for :taggings
  attr_accessible :author, :position unless Rails::VERSION::MAJOR > 3 && !defined? ProtectedAttributes
  field :published_at, type: DateTime
}, after: 'include Mongoid::Document'
copy_file spec_dir.join('support/templates/post_decorator.rb'), "app/models/post_decorator.rb"

generate :model, "blog/post title:string body:text position:integer starred:boolean foo_id:integer"
inject_into_file 'app/models/blog/post.rb', %q{
  include Mongoid::Timestamps
  belongs_to :category
  belongs_to :author, class_name: 'User', inverse_of: nil
  has_many :taggings
  accepts_nested_attributes_for :author
  accepts_nested_attributes_for :taggings
  attr_accessible :author, :position unless Rails::VERSION::MAJOR > 3 && !defined? ProtectedAttributes
  field :published_at, type: DateTime
}, after: 'include Mongoid::Document'

generate :model, "user type:string first_name:string last_name:string username:string age:integer"
inject_into_file 'app/models/user.rb', %q{
  has_many :posts, class_name: 'Post', inverse_of: 'author'
  def display_name
    "#{first_name} #{last_name}"
  end
}, after: 'include Mongoid::Document'

generate :model, 'publisher --parent=User'
generate :model, 'category name:string description:text'
inject_into_file 'app/models/category.rb', %q{
  has_many :posts
  accepts_nested_attributes_for :posts
}, after: 'include Mongoid::Document'
generate :model, 'store name:string'

# Generate a model with string ids
generate :model, "tag name:string"

inject_into_file 'app/models/tag.rb', %q{
  # self.primary_key = :id
  # before_create :set_id

  # private
  # def set_id
  #   self.id = 8.times.inject("") { |s,e| s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }
  # end
}, after: 'include Mongoid::Document'

generate :model, "tagging"
inject_into_file 'app/models/tagging.rb', %q{
  belongs_to :post
  belongs_to :tag
}, after: 'include Mongoid::Document'

# Configure default_url_options in test environment
inject_into_file "config/environments/test.rb", "  config.action_mailer.default_url_options = { host: 'example.com' }\n", after: "config.cache_classes = true\n"

# Add our local Active Admin to the load path
inject_into_file "config/environment.rb", "\n$LOAD_PATH.unshift('#{File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))}')\nrequire \"active_admin\"\n", after: "require File.expand_path('../application', __FILE__)"
# inject_into_file "config/application.rb", "\nrequire 'devise'\n", after: "require 'rails/all'"

# Force strong parameters to raise exceptions
inject_into_file 'config/application.rb', "\n\n    config.action_controller.action_on_unpermitted_parameters = :raise if Rails::VERSION::MAJOR == 4\n\n", after: 'class Application < Rails::Application'

# Add some translations
append_file "config/locales/en.yml", File.read(spec_dir.join('support/templates/en.yml'))

# Add predefined admin resources
directory spec_dir.join('support/templates/admin'), "app/admin"

# Add predefined policies
directory spec_dir.join('support/templates/policies'), 'app/policies'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

generate 'active_admin:install'

# temprorary fix for devise issue: https://github.com/plataformatec/devise/issues/2949
inject_into_file 'app/models/admin_user.rb', %q{
  def self.serialize_from_session(key, salt)
    record = to_adapter.get(key[0]["$oid"])
    record if record && record.authenticatable_salt == salt
  end
}, after: '# field :locked_at,       type: Time'

inject_into_file "config/routes.rb", "\n  root to: redirect('/admin')", after: /.*::Application.routes.draw do/
remove_file "public/index.html" if File.exists? "public/index.html"

# Devise master doesn't set up its secret key on Rails 4.1
# https://github.com/plataformatec/devise/issues/2554
gsub_file 'config/initializers/devise.rb', /# config.secret_key =/, 'config.secret_key ='

# if ENV['INSTALL_PARALLEL']
#   inject_into_file 'config/database.yml', "<%= ENV['TEST_ENV_NUMBER'] %>", after: 'test.sqlite3'
#   inject_into_file 'config/database.yml', "<%= ENV['TEST_ENV_NUMBER'] %>", after: 'cucumber.sqlite3', force: true

#   # Note: this is hack!
#   # Somehow, calling parallel_tests tasks from Rails generator using Thor does not work ...
#   # RAILS_ENV variable never makes it to parallel_tests tasks.
#   # We need to call these tasks in the after set up hook in order to creates cucumber DBs + run migrations on test & cucumber DBs
#   create_file 'lib/tasks/parallel.rake', %q{
# namespace :parallel do
#   def run_in_parallel(cmd, options)
#     count = "-n #{options[:count]}" if options[:count]
#     executable = 'parallel_test'
#     command = "#{executable} --exec '#{cmd}' #{count} #{'--non-parallel' if options[:non_parallel]}"
#     abort unless system(command)
#   end

#   desc "create cucumber databases via db:create --> parallel:create_cucumber_db[num_cpus]"
#   task :create_cucumber_db, :count do |t, args|
#     run_in_parallel("rake db:create RAILS_ENV=cucumber", args)
#   end

#   desc "load dumped schema for cucumber databases"
#   task :load_schema_cucumber_db, :count do |t,args|
#     run_in_parallel("rake db:schema:load RAILS_ENV=cucumber", args)
#   end
# end
# }
# end
