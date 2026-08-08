# frozen_string_literal: true

module RailsTablePreferences
  class PreferencesController < ApplicationController
    before_action :validate_table_key!
    before_action :require_owner_for_owner_write!, only: %i[create update destroy]

    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failure
    rescue_from ActiveRecord::RecordNotDestroyed, with: :render_destroy_failure

    def index
      preferences = Preference.available_to(
        user: table_preferences_current_user,
        scope_context: table_preferences_scope_context
      ).for_table(table_key)
       .order(default_flag: :desc, name: :asc)

      render json: {
        table_key: table_key,
        preferences: preferences.map { |preference| preference_payload(preference) }
      }
    end

    def show
      preference = resolved_preference

      return render_preference_not_found if preference.nil? && explicit_preference_request?

      render json: preference_payload(preference)
    end

    def create
      preference = Preference.new(
        user: owner_for_write_scope,
        scope_type: scope_type_param,
        scope_key: scope_key_param,
        table_key: table_key,
        name: normalized_preference_name,
        settings: SettingsNormalizer.call(settings_params),
        default_flag: default_param?
      )
      save_default_preference(preference)

      render json: preference_payload(preference), status: :created
    end

    def update
      preference = Preference.find_or_initialize_for(
        user: table_preferences_current_user,
        table_key: table_key,
        name: preference_name,
        scope_type: scope_type_param,
        scope_key: scope_key_param
      )
      preference.user = owner_for_write_scope
      preference.scope_type = scope_type_param
      preference.scope_key = scope_key_param
      preference.settings = SettingsNormalizer.call(settings_params)
      preference.default_flag = default_param? if params.key?(:default)
      save_default_preference(preference)

      render json: preference_payload(preference), status: :ok
    end

    def destroy
      preference = Preference.find_for(
        user: table_preferences_current_user,
        table_key: table_key,
        name: preference_name,
        scope_type: scope_type_param,
        scope_key: scope_key_param
      )
      preference&.destroy!

      head :no_content
    end

    private

    def resolved_preference
      return explicitly_scoped_preference if explicit_scope_param?
      return default_preference if preference_name == "default"

      Preference.available_named_preference(
        user: table_preferences_current_user,
        table_key: table_key,
        name: preference_name,
        scope_context: table_preferences_scope_context
      )
    end

    def explicitly_scoped_preference
      Preference.find_for(
        user: table_preferences_current_user,
        table_key: table_key,
        name: preference_name,
        scope_type: scope_type_param,
        scope_key: scope_key_param
      )
    end

    def default_preference
      Preference.default_for(
        user: table_preferences_current_user,
        table_key: table_key,
        scope_context: table_preferences_scope_context
      )
    end

    def preference_name
      (params[:name].presence || params[:preference_name].presence || "default").to_s
    end

    def normalized_preference_name
      preference_name.strip.presence || "default"
    end

    def table_key
      request.path_parameters[:table_key].to_s.strip
    end

    def scope_type_param
      params[:scope_type].presence || Preference::OWNER_SCOPE_TYPE
    end

    def scope_key_param
      params[:scope_key].presence
    end

    def explicit_scope_param?
      params[:scope_type].present? || params[:scope_key].present?
    end

    def explicit_preference_request?
      explicit_scope_param? || preference_name != "default"
    end

    def render_preference_not_found
      render json: { error: "not_found", message: "Preference not found" }, status: :not_found
    end

    def validate_table_key!
      return if table_key.present?

      render json: { error: "invalid_request", message: "table_key is required" }, status: :bad_request
    end

    def require_owner_for_owner_write!
      return unless scope_type_param == Preference::OWNER_SCOPE_TYPE
      return if table_preferences_current_user.present?

      render json: { error: "owner_required", message: "A current owner is required for owner preset writes" }, status: :unauthorized
    end

    def render_validation_failure(error)
      record = error.record
      render json: {
        error: "validation_failed",
        message: "Preference could not be saved",
        details: record&.errors&.to_hash(true) || {}
      }, status: :unprocessable_entity
    end

    def render_destroy_failure(error)
      record = error.record
      render json: {
        error: "destroy_failed",
        message: "Preference could not be deleted",
        details: record&.errors&.to_hash(true) || {}
      }, status: :unprocessable_entity
    end

    def owner_for_write_scope
      scope_type_param == Preference::OWNER_SCOPE_TYPE ? table_preferences_current_user : nil
    end

    def default_param?
      return false unless params.key?(:default)

      ActiveModel::Type::Boolean.new.cast(params[:default])
    end

    def settings_params
      raw_settings = params[:settings]

      case raw_settings
      when ActionController::Parameters
        raw_settings.permit!.to_h
      when Hash
        raw_settings
      else
        {}
      end
    end

    def save_default_preference(preference)
      Preference.transaction do
        clear_other_defaults(preference) if preference.default_flag?
        preference.save!
      end
    end

    def clear_other_defaults(preference)
      Preference.for_scope(preference.scope_type, preference.scope_key)
                .where(RailsTablePreferences.configuration.user_foreign_key => preference.user_id)
                .for_table(preference.table_key)
                .where.not(id: preference.id)
                .update_all(default_flag: false)
    end

    def preference_payload(preference)
      settings = preference&.settings || SettingsNormalizer.call({})

      {
        table_key: table_key,
        name: preference&.name || preference_name,
        default: preference&.default_flag || false,
        scope_type: preference&.scope_type || scope_type_param,
        scope_key: preference&.scope_key,
        scope_label: preference&.scope_label || scope_type_param,
        editable: preference ? preference.editable_by_owner?(table_preferences_current_user) : table_preferences_current_user.present?,
        settings: settings
      }
    end
  end
end
