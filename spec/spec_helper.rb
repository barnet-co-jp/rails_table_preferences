# frozen_string_literal: true

require "bundler/setup"
require "erb"
require "fileutils"
require "pathname"
require_relative "test_application"
require "capybara"
require "capybara/dsl"
require "rspec/rails"
require "selenium-webdriver"

Capybara.app = Rails.application
Capybara.server = :puma, { Silent: true }
Capybara.register_driver :rails_table_preferences_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[headless=new disable-gpu no-sandbox disable-dev-shm-usage window-size=1400,1200].each do |argument|
    options.add_argument(argument)
  end

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :members, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :table_preferences, force: true do |t|
    t.references :user, null: true
    t.references :member, null: true
    t.string :scope_type, null: false, default: "owner"
    t.string :scope_key, null: false, default: ""
    t.string :table_key, null: false
    t.string :name, null: false, default: "default"
    t.json :settings, null: false
    t.boolean :default_flag, null: false, default: false
    t.timestamps
  end

  add_index :table_preferences, [:scope_type, :scope_key, :user_id, :table_key, :name], unique: true, name: "idx_table_preferences_scope_table_name"
end

class User < ActiveRecord::Base
end

class Member < ActiveRecord::Base
end

module GeneratorSpecHelpers
  def file(path)
    Pathname.new(destination_root).join(path)
  end
end

RSpec.configure do |config|
  config.include FileUtils, type: :generator
  config.include GeneratorSpecHelpers, type: :generator
  config.include Capybara::DSL, type: :system

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.infer_spec_type_from_file_location!

  config.before(type: :system) do
    driven_by :rack_test
  end

  config.before(type: :system, js: true) do
    driven_by :rails_table_preferences_headless_chrome
  end

  config.before do
    RailsTablePreferences.configuration = RailsTablePreferences::Configuration.new
    RailsTablePreferences.configuration.scope_context_method = :table_preference_scope_context
    RailsTablePreferences::Preference.table_name = RailsTablePreferences.configuration.table_name
    RailsTablePreferences::Preference.delete_all
    User.delete_all
    Member.delete_all
    Thread.current[:rails_table_preferences_current_user] = nil
    Thread.current[:rails_table_preferences_scope_context] = nil
  end

  config.after do
    Thread.current[:rails_table_preferences_current_user] = nil
    Thread.current[:rails_table_preferences_scope_context] = nil
  end

  config.after(type: :system) do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
