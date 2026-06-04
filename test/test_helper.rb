require "simplecov"
SimpleCov.start

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# Framework definitions are reference data. Seed them once (outside the per-test
# transaction) so they persist for the whole suite, like fixtures. Idempotent.
FrameworkSeeder.seed_all!

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  include FactoryBot::Syntax::Methods
  # Add more helper methods to be used by all tests here...
end
