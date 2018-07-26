require 'spec_helper'

ENV['RAILS_ENV'] = 'test'

ENV['RAILS_ROOT'] = if ENV['MONGOID']
  File.expand_path("../mongoid/rails/rails-#{ENV['RAILS']}", __FILE__)
else
  File.expand_path("../rails/rails-#{ENV['RAILS']}", __FILE__)
end

# Create the test app if it doesn't exists
unless File.exists?(ENV['RAILS_ROOT'])
  if ENV['MONGOID']
    system 'rake mongoid:setup'
  else
    system 'rake setup'
  end
end

require 'rails'
require 'active_record' unless ENV['MONGOID']
require 'mongoid' if ENV['MONGOID']
require 'active_admin'
require 'devise'
ActiveAdmin.application.load_paths = [ENV['RAILS_ROOT'] + "/app/admin"]

require ENV['RAILS_ROOT'] + '/config/environment'

require 'rspec/rails'

# Prevent Test::Unit's AutoRunner from executing during RSpec's rake task on
# JRuby
Test::Unit.run = true if defined?(Test::Unit) && Test::Unit.respond_to?(:run=)

# Disabling authentication in specs so that we don't have to worry about
# it allover the place
ActiveAdmin.application.authentication_method = false
ActiveAdmin.application.current_user_method = false

RSpec.configure do |config|
  config.use_transactional_fixtures = true unless ENV['MONGOID']
  config.use_instantiated_fixtures = false unless ENV['MONGOID']
  config.include Devise::TestHelpers, type: :controller
  config.render_views = false
  config.filter_run focus: true
  config.filter_run_excluding skip: true
  config.run_all_when_everything_filtered = true
  config.color = true
  config.order = :random

  devise = ActiveAdmin::Dependency.devise >= '4.2' ? Devise::Test::ControllerHelpers : Devise::TestHelpers
  config.include devise, type: :controller

  require 'support/active_admin_integration_spec_helper'
  config.include ActiveAdminIntegrationSpecHelper

  require 'support/active_admin_request_helpers'
  config.include ActiveAdminRequestHelpers, type: :request

  # Setup Some Admin stuff for us to play with
  config.before(:suite) do
    ActiveAdminIntegrationSpecHelper.load_defaults!
    ActiveAdminIntegrationSpecHelper.reload_routes!
  end
end

# Force deprecations to raise an exception.
# This would set `behavior = :raise`, but that wasn't added until Rails 4.
ActiveSupport::Deprecation.behavior = -> message, callstack do
  e = StandardError.new message
  e.set_backtrace callstack.map(&:to_s)
  raise e
end

# improve the performance of the specs suite by not logging anything
# see http://blog.plataformatec.com.br/2011/12/three-tips-to-improve-the-performance-of-your-test-suite/
Rails.logger.level = Logger::FATAL

# Improves performance by forcing the garbage collector to run less often.
unless ENV['DEFER_GC'] == '0' || ENV['DEFER_GC'] == 'false'
  require 'support/deferred_garbage_collection'
  RSpec.configure do |config|
    config.before(:all) { DeferredGarbageCollection.start }
    config.after(:all)  { DeferredGarbageCollection.reconsider }
  end
end

# Make input type=hidden visible
Capybara.ignore_hidden_elements = false
