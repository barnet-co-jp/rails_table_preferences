# frozen_string_literal: true

module RailsTablePreferences
  class Preference < ApplicationRecord
    OWNER_SCOPE_TYPE = "owner"
    SHARED_SCOPE_TYPE = "shared"
    ROLE_SCOPE_TYPE = "role"
    ORGANIZATION_SCOPE_TYPE = "organization"
    VALID_SCOPE_TYPES = [OWNER_SCOPE_TYPE, SHARED_SCOPE_TYPE, ROLE_SCOPE_TYPE, ORGANIZATION_SCOPE_TYPE].freeze

    self.table_name = RailsTablePreferences.configuration.table_name

    belongs_to :user,
               class_name: RailsTablePreferences.configuration.user_class_name,
               foreign_key: RailsTablePreferences.configuration.user_foreign_key,
               inverse_of: false,
               optional: true

    validates :table_key, presence: true
    validates :name, presence: true
    validates :settings, presence: true
    validates :scope_type, presence: true, inclusion: { in: VALID_SCOPE_TYPES }
    validates :scope_key, presence: true, if: :named_scope?
    validates RailsTablePreferences.configuration.user_foreign_key, presence: true, if: :owner_scope?
    validates :name, uniqueness: { scope: [:scope_type, :scope_key, RailsTablePreferences.configuration.user_foreign_key, :table_key] }

    scope :for_user, ->(user) { where(scope_type: OWNER_SCOPE_TYPE, scope_key: "", RailsTablePreferences.configuration.user_foreign_key => user) }
    scope :shared, -> { where(scope_type: SHARED_SCOPE_TYPE, scope_key: "", RailsTablePreferences.configuration.user_foreign_key => nil) }
    scope :for_role, ->(role_key) { where(scope_type: ROLE_SCOPE_TYPE, scope_key: role_key.to_s, RailsTablePreferences.configuration.user_foreign_key => nil) }
    scope :for_organization, ->(organization_key) { where(scope_type: ORGANIZATION_SCOPE_TYPE, scope_key: organization_key.to_s, RailsTablePreferences.configuration.user_foreign_key => nil) }
    scope :for_scope, ->(scope_type, scope_key = nil) do
      normalized_scope_type = scope_type.to_s.presence || OWNER_SCOPE_TYPE
      normalized_scope_key = [OWNER_SCOPE_TYPE, SHARED_SCOPE_TYPE].include?(normalized_scope_type) ? "" : scope_key.to_s
      where(scope_type: normalized_scope_type, scope_key: normalized_scope_key)
    end
    scope :for_table, ->(table_key) { where(table_key: table_key.to_s) }
    scope :defaults, -> { where(default_flag: true) }
    scope :available_to, ->(user:, scope_context: {}) do
      context = scope_context || {}
      relation = none
      relation = relation.or(for_user(user)) if user
      relation = relation.or(shared)
      Array(context[:roles] || context["roles"]).each do |role_key|
        relation = relation.or(for_role(role_key)) if role_key.present?
      end
      organization_key = context[:organization] || context["organization"] || context[:organization_key] || context["organization_key"]
      relation = relation.or(for_organization(organization_key)) if organization_key.present?
      relation
    end

    before_validation :normalize_name, :set_default_name, :set_default_settings, :set_default_scope_type, :set_default_scope_key

    def self.find_for(user:, table_key:, name: "default", scope_type: OWNER_SCOPE_TYPE, scope_key: nil)
      relation = for_scope(scope_type, scope_key).where(RailsTablePreferences.configuration.user_foreign_key => scope_type.to_s == OWNER_SCOPE_TYPE ? user : nil)
      table_relation = relation.for_table(table_key)
      raw_name, normalized_name = lookup_names(name)
      table_relation.find_by(name: raw_name) || (table_relation.find_by(name: normalized_name) unless normalized_name == raw_name)
    end

    def self.find_or_initialize_for(user:, table_key:, name: "default", scope_type: OWNER_SCOPE_TYPE, scope_key: nil)
      relation = for_scope(scope_type, scope_key).where(RailsTablePreferences.configuration.user_foreign_key => scope_type.to_s == OWNER_SCOPE_TYPE ? user : nil)
      table_relation = relation.for_table(table_key)
      raw_name, normalized_name = lookup_names(name)
      table_relation.find_by(name: raw_name) ||
        (table_relation.find_by(name: normalized_name) unless normalized_name == raw_name) ||
        table_relation.new(name: normalized_name)
    end

    def self.default_for(user:, table_key:, scope_context: {})
      available_to(user: user, scope_context: scope_context).for_table(table_key).defaults.order(Arel.sql(scope_priority_case), :name).first || find_for(user: user, table_key: table_key, name: "default")
    end

    def self.available_named_preference(user:, table_key:, name:, scope_context: {})
      raw_name, normalized_name = lookup_names(name)
      exact_name_order = connection.quote(raw_name)
      available_to(user: user, scope_context: scope_context)
        .for_table(table_key)
        .where(name: [raw_name, normalized_name].uniq)
        .order(Arel.sql(scope_priority_case), Arel.sql("CASE WHEN name = #{exact_name_order} THEN 0 ELSE 1 END"), :name)
        .first
    end

    def self.lookup_names(name)
      raw_name = name.to_s
      [raw_name, raw_name.strip.presence || "default"]
    end

    def shared?
      scope_type == SHARED_SCOPE_TYPE
    end

    def owner_scope?
      scope_type.blank? || scope_type == OWNER_SCOPE_TYPE
    end

    def named_scope?
      [ROLE_SCOPE_TYPE, ORGANIZATION_SCOPE_TYPE].include?(scope_type)
    end

    def editable_by_owner?(owner)
      owner_scope? && user == owner
    end

    def scope_label
      case scope_type
      when OWNER_SCOPE_TYPE then "owner"
      when SHARED_SCOPE_TYPE then "shared"
      when ROLE_SCOPE_TYPE then "role:#{scope_key}"
      when ORGANIZATION_SCOPE_TYPE then "organization:#{scope_key}"
      else scope_type.to_s
      end
    end

    def self.scope_priority_case
      <<~SQL.squish
        CASE scope_type
        WHEN 'owner' THEN 0
        WHEN 'role' THEN 1
        WHEN 'organization' THEN 2
        WHEN 'shared' THEN 3
        ELSE 9
        END
      SQL
    end

    private

    def normalize_name
      self.name = name.to_s.strip if name
    end

    def set_default_name
      self.name = "default" if name.blank?
    end

    def set_default_settings
      self.settings = { "columns" => [], "filters" => {}, "sorts" => [] } if settings.blank?
    end

    def set_default_scope_type
      self.scope_type = OWNER_SCOPE_TYPE if scope_type.blank?
    end

    def set_default_scope_key
      self.scope_key = "" if [OWNER_SCOPE_TYPE, SHARED_SCOPE_TYPE].include?(scope_type)
    end
  end
end
