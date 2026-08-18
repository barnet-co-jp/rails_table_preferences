# frozen_string_literal: true

require "active_support/inflector"
require "rails/generators"
require "rails/generators/active_record"

module RailsTablePreferences
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      ENGINE_ROUTE = 'mount RailsTablePreferences::Engine, at: "/rails_table_preferences"'
      ENGINE_ROUTE_PATH = "/rails_table_preferences"
      ENGINE_ROUTE_PATTERN = /mount\s*(?:\(\s*)?RailsTablePreferences::Engine\s*,\s*at:\s*["']#{Regexp.escape(ENGINE_ROUTE_PATH)}["']/.freeze
      DEMO_ROUTE = 'get "/rails_table_preferences_demo/orders", to: "rails_table_preferences_demo/orders#index"'
      DEMO_ROUTE_PATH = "/rails_table_preferences_demo/orders"
      DEMO_ROUTE_TO = "rails_table_preferences_demo/orders#index"
      DEMO_ROUTE_PATTERN = /get\s*(?:\(\s*)?["']#{Regexp.escape(DEMO_ROUTE_PATH)}["']\s*,\s*to:\s*["']#{Regexp.escape(DEMO_ROUTE_TO)}["']/.freeze

      class_option :owner_model,
                   type: :string,
                   default: "users",
                   desc: "Model that owns table preferences. String or symbol-like, singular or plural, e.g. users, customers, client."

      class_option :owner_foreign_key,
                   type: :string,
                   default: nil,
                   desc: "Foreign key column for the owner model. Must end with _id to match the generated t.references migration."

      class_option :skip_javascript,
                   type: :boolean,
                   default: false,
                   desc: "Skip copying the Stimulus controller. Use with the package entrypoint or a host-owned controller."

      class_option :skip_stylesheets,
                   type: :boolean,
                   default: false,
                   desc: "Skip copying the default stylesheet into app/assets/stylesheets."

      class_option :with_engine_route,
                   type: :boolean,
                   default: false,
                   desc: "Also mount the Rails Table Preferences JSON API engine in config/routes.rb."

      class_option :with_demo,
                   type: :boolean,
                   default: false,
                   desc: "Copy a lightweight demo controller and view for local browser verification."

      class_option :with_demo_route,
                   type: :boolean,
                   default: false,
                   desc: "Also add the demo route to config/routes.rb. Implies --with-demo."

      desc "Copies Rails Table Preferences migrations, initializer, JavaScript, and stylesheets into the host application."

      def ensure_owner_foreign_key_uses_reference_column
        validate_owner_foreign_key!(owner_foreign_key)
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/rails_table_preferences.rb"
      end

      def copy_migration
        migration_template "create_table_preferences.rb", "db/migrate/create_table_preferences.rb"
      end

      def copy_javascript
        return if options[:skip_javascript]

        invoke "rails_table_preferences:javascript"
      end

      def copy_stylesheets
        return if options[:skip_stylesheets]

        invoke "rails_table_preferences:stylesheets"
      end

      def copy_demo
        return unless demo_requested?

        copy_file "demo/orders_controller.rb", "app/controllers/rails_table_preferences_demo/orders_controller.rb"
        copy_file "demo/index.html.erb", "app/views/rails_table_preferences_demo/orders/index.html.erb"
      end

      def add_engine_route
        return unless options[:with_engine_route]

        routes_path = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes_path) && engine_route_present?(File.read(routes_path))
          say_status :identical, "config/routes.rb"
        else
          route ENGINE_ROUTE
        end
      end

      def add_demo_route
        return unless options[:with_demo_route]

        routes_path = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes_path) && demo_route_present?(File.read(routes_path))
          say_status :identical, "config/routes.rb"
        else
          route DEMO_ROUTE
        end
      end

      def show_post_install_message
        say "\nRails Table Preferences installed.", :green
        say "\nNext steps:"

        post_install_steps.each.with_index(1) do |lines, index|
          say "  #{index}. #{lines.first}"
          lines.drop(1).each { |line| say line }
        end

        say ""
      end

      def owner_class_name
        owner_model.classify
      end

      def owner_foreign_key
        key = options[:owner_foreign_key].presence || owner_class_name.foreign_key
        validate_owner_foreign_key!(key)
        key
      end

      def owner_table_name
        owner_class_name.tableize
      end

      def owner_model
        options[:owner_model].to_s
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      private

      def validate_owner_foreign_key!(key)
        return if key.to_s.end_with?("_id")

        raise Thor::Error,
              "--owner-foreign-key must end with _id so the generated t.references column matches the table_preferences indexes. " \
              "Use --owner-model for normal owner references; custom UUID or string owner keys need a hand-written migration."
      end

      def post_install_steps
        steps = [
          ["Run: bin/rails db:migrate"],
          [
            "Before writing custom RTP integration code, read the integration guidance bundled with the installed gem.",
            "     Locate the exact bundled version with: bundle show rails_table_preferences",
            '     Read: $(bundle show rails_table_preferences)/docs/host_app_integration_guardrails.md',
            '     Read: $(bundle show rails_table_preferences)/docs/decision_guide.md',
            "     Prefer public APIs, helpers, package entrypoints, and lifecycle events before querying RTP models or overriding controller internals."
          ],
          [
            engine_route_step_heading,
            "       #{ENGINE_ROUTE}",
            "     If you use a custom initializer mount_path, update the route path manually to match it."
          ]
        ]

        unless options[:skip_stylesheets]
          steps << [
            "Ensure app/assets/stylesheets/rails_table_preferences.css is loaded by your application stylesheet.",
            "     For Sprockets, add this if needed:",
            "       *= require rails_table_preferences",
            "     For Sass/CSS bundling, import the copied file from your application stylesheet."
          ]
        end

        steps << if options[:skip_javascript]
                   [
                     "Register either a host-owned controller or the package entrypoint with the rails-table-preferences Stimulus name.",
                     "     Package entrypoint example: import rails_table_preferences/controller and register it from your app entrypoint.",
                     "     See docs/javascript_entrypoints.md for Vite/app/frontend resolver notes."
                   ]
                 else
                   [
                     "Ensure the copied Stimulus controller is registered.",
                     "     stimulus-rails default manifests usually register app/javascript/controllers/*_controller.js automatically.",
                     "     For Vite/app/frontend package entrypoint installs, rerun with --skip-javascript and register rails_table_preferences/controller manually.",
                     "     See docs/javascript_entrypoints.md for resolver notes."
                   ]
                 end

        if demo_requested?
          steps << [
            demo_route_step_heading,
            "       #{DEMO_ROUTE}",
            "     The demo uses the configured current-user method and the table_preferences table.",
            "     Remove the copied demo controller/view and route before production release if they are not needed."
          ]
        end

        steps
      end

      def engine_route_step_heading
        if options[:with_engine_route]
          "Engine route configured in config/routes.rb:"
        else
          "Mount the engine in config/routes.rb, or rerun with --with-engine-route:"
        end
      end

      def demo_route_step_heading
        if options[:with_demo_route]
          "Demo route configured in config/routes.rb:"
        else
          "Add this route if you want to open the copied demo screen, or rerun with --with-demo-route:"
        end
      end

      def demo_requested?
        options[:with_demo] || options[:with_demo_route]
      end

      def engine_route_present?(routes_source)
        routes_source.match?(ENGINE_ROUTE_PATTERN)
      end

      def demo_route_present?(routes_source)
        routes_source.match?(DEMO_ROUTE_PATTERN)
      end
    end
  end
end
