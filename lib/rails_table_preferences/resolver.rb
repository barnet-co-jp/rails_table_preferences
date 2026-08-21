# frozen_string_literal: true

module RailsTablePreferences
  class Resolver
    class << self
      def preference(owner:, table_key:, name: nil, scope_context: {})
        return unless owner

        context = scope_context || {}
        unless name.to_s.strip.empty?
          return RailsTablePreferences::Preference.available_named_preference(
            user: owner,
            table_key: table_key,
            name: name,
            scope_context: context
          )
        end

        RailsTablePreferences::Preference.default_for(
          user: owner,
          table_key: table_key,
          scope_context: context
        )
      end

      def settings(owner:, table_key:, name: nil, scope_context: {}, fallback: {})
        resolved = preference(
          owner: owner,
          table_key: table_key,
          name: name,
          scope_context: scope_context
        )

        RailsTablePreferences::SettingsNormalizer.call(resolved&.settings || fallback || {})
      end
    end
  end
end
