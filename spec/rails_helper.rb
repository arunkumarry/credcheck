# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # Wrap each example in a transaction so the DB is rolled back after each test.
  config.use_transactional_fixtures = true

  # Automatically infer spec type from file location.
  # spec/controllers → :controller, spec/services → :unit, etc.
  config.infer_spec_type_from_file_location!

  # Filter Rails internal lines from backtraces.
  config.filter_rails_from_backtrace!

  # FactoryBot DSL — use `create(:user)` instead of `FactoryBot.create(:user)`
  config.include FactoryBot::Syntax::Methods

  # Helpers for signing in users via Rails 8 Authentication generator
  config.include ActiveSupport::Testing::Assertions
end

# Shoulda::Matchers — provides `validate_presence_of`, `belong_to`, etc.
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
