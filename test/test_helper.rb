# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

#Run any available migration
#ActiveRecord::Migrator.migrate 'up'
load 'dummy/db/schema.rb'

# Set fixtures root
ActiveSupport::TestCase.fixture_path=(File.expand_path("../dummy/test/fixtures",  __FILE__))
ActiveSupport::TestCase.fixtures :all

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
