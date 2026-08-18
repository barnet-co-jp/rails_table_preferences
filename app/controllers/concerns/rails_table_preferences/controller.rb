# frozen_string_literal: true

module RailsTablePreferences
  module Controller
    extend ActiveSupport::Concern

    # Returns the saved preference for the given table.
    #
    # Resolution rule:
    # - explicit name: use the first available preset with that name
    # - no name: use default_flag=true first
    # - fallback: use owner name="default"
    # - missing preference: return nil
    #
    # Available presets are resolved in this priority order:
    # owner, role, organization, shared.
    def rails_table_preference(table_key:, name: nil, owner: nil, scope_context: nil)
      owner ||= rails_table_preferences_current_owner
      return unless owner

      scope_context = rails_table_preferences_scope_context if scope_context.nil?
      RailsTablePreferences.resolve_preference(
        owner: owner,
        table_key: table_key,
        name: name,
        scope_context: scope_context
      )
    end

    def rails_table_preference_settings(table_key:, name: nil, owner: nil, scope_context: nil, fallback: {})
      owner ||= rails_table_preferences_current_owner
      scope_context = rails_table_preferences_scope_context if scope_context.nil?

      RailsTablePreferences.resolve_settings(
        owner: owner,
        table_key: table_key,
        name: name,
        scope_context: scope_context,
        fallback: fallback
      )
    end

    # Converts saved table preference filters/sorts into params for the host app.
    #
    # adapter: :controller_params returns a plain params hash suitable for existing
    #   search(params) / order_by(params[:sort]) style controllers.
    # adapter: :ransack returns Ransack-compatible params.
    # namespace: wraps the converted params in a nested hash such as { "q" => ... }.
    def rails_table_preference_params(table_key:, columns:, name: nil, owner: nil, scope_context: nil, adapter: :controller_params, sort_param: "sort", namespace: nil, fallback: {})
      settings = rails_table_preference_settings(table_key: table_key, name: name, owner: owner, scope_context: scope_context, fallback: fallback)
      adapter_params = rails_table_preference_adapter_params(
        adapter: adapter,
        settings: settings,
        columns: columns,
        sort_param: sort_param
      )
      rails_table_preferences_namespace_params(adapter_params, namespace: namespace)
    end

    # Returns an ordered export payload for CSV, Excel, or report generation.
    #
    # Rails Table Preferences does not generate the export file. The host app can
    # use this payload to decide which columns and headers to export.
    def rails_table_preference_export_payload(table_key:, columns:, name: nil, owner: nil, scope_context: nil, include_hidden: false, fallback: {})
      settings = rails_table_preference_settings(
        table_key: table_key,
        name: name,
        owner: owner,
        scope_context: scope_context,
        fallback: fallback
      )

      RailsTablePreferences::ExportPayload.call(
        settings: settings,
        columns: columns,
        include_hidden: include_hidden
      )
    end

    # Convenience method for apps that want to merge saved preference filters into
    # the current controller params before passing them to a model search method.
    def rails_table_preference_merged_params(params_source = params, **options)
      base_params = rails_table_preferences_hash_from_params(params_source)
      base_params.merge(rails_table_preference_params(**options))
    end

    private

    def rails_table_preference_adapter_params(adapter:, settings:, columns:, sort_param:)
      case adapter.to_sym
      when :controller_params, :plain_params, :params
        RailsTablePreferences::Adapters::ControllerParams.to_params(
          filters: settings["filters"],
          sorts: settings["sorts"],
          columns: columns,
          sort_param: sort_param
        )
      when :ransack
        RailsTablePreferences::Adapters::Ransack.to_params(
          filters: settings["filters"],
          sorts: settings["sorts"]
        )
      else
        raise ArgumentError, "Unsupported table preference adapter: #{adapter.inspect}"
      end
    end

    def rails_table_preferences_namespace_params(params_hash, namespace: nil)
      return params_hash if namespace.blank?

      { namespace.to_s => params_hash }
    end

    def rails_table_preferences_current_owner
      send(RailsTablePreferences.configuration.current_user_method)
    end

    def rails_table_preferences_scope_context
      method_name = RailsTablePreferences.configuration.scope_context_method
      return {} if method_name.blank?
      return {} unless respond_to?(method_name, true)

      context = send(method_name)
      context.respond_to?(:to_h) ? context.to_h : {}
    end

    def rails_table_preferences_hash_from_params(params_source)
      case params_source
      when ActionController::Parameters
        params_source.to_unsafe_h
      when Hash
        params_source.stringify_keys
      else
        {}
      end
    end
  end
end
