# frozen_string_literal: true

require_relative "lib/rails_table_preferences/version"

Gem::Specification.new do |spec|
  spec.name = "rails_table_preferences"
  spec.version = RailsTablePreferences::VERSION
  spec.authors = ["Haruhito Matsuo"]
  spec.email = ["matsuo@scrumsoftware.co.jp"]

  spec.summary = "Table display preferences for Rails applications."
  spec.description = "Rails Table Preferences saves and restores table display settings such as column visibility, order, width, truncation, filters, sorts, presets, fixed columns, groups, and export column order."
  spec.homepage = "https://github.com/barnet-co-jp/rails_table_preferences"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/docs/index.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "{app,config,docs,lib}/**/*",
      "CHANGELOG.md",
      "LICENSE",
      "package.json",
      "README.md"
    ].select { |path| File.file?(path) }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0", "< 9.0"

  spec.add_development_dependency "capybara", ">= 3.39"
  spec.add_development_dependency "puma", ">= 6.0"
  spec.add_development_dependency "rspec-rails", ">= 6.0"
  spec.add_development_dependency "selenium-webdriver", ">= 4.22"
  spec.add_development_dependency "sqlite3", ">= 1.6"
end
