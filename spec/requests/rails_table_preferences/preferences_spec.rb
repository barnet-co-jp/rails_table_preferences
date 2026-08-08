# frozen_string_literal: true

RSpec.describe "RailsTablePreferences::Preferences", type: :request do
  let(:user) { User.create!(name: "User 1") }

  before do
    Thread.current[:rails_table_preferences_current_user] = user
  end

  def force_record_invalid(preference)
    preference.errors.add(:base, "forced failure")
    ActiveRecord::RecordInvalid.new(preference)
  end

  describe "GET /rails_table_preferences/preferences/:table_key" do
    it "returns preferences available to the current user and table" do
      RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )
      RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] }
      )
      RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "shared-default",
        settings: { "columns" => [] }
      )

      get "/rails_table_preferences/preferences/orders"

      expect(response).to have_http_status(:ok)
      preferences = JSON.parse(response.body)["preferences"]
      expect(preferences.map { |preference| preference["name"] }).to eq(%w[default inspection shared-default])
      expect(preferences.last["scope_type"]).to eq("shared")
      expect(preferences.last["editable"]).to eq(false)
    end

    it "returns role and organization scoped preferences from the configured scope context" do
      Thread.current[:rails_table_preferences_scope_context] = { roles: ["admin"], organization: "tokyo" }
      RailsTablePreferences::Preference.create!(
        scope_type: "role",
        scope_key: "admin",
        table_key: "orders",
        name: "admin-view",
        settings: { "columns" => [] }
      )
      RailsTablePreferences::Preference.create!(
        scope_type: "organization",
        scope_key: "tokyo",
        table_key: "orders",
        name: "tokyo-view",
        settings: { "columns" => [] }
      )

      get "/rails_table_preferences/preferences/orders"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["preferences"].map { |preference| preference["name"] }).to eq(%w[admin-view tokyo-view])
    end

    it "accepts table keys containing dots" do
      RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders.index",
        name: "default",
        settings: { "columns" => [] }
      )

      get "/rails_table_preferences/preferences/orders.index"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["preferences"].map { |preference| preference["name"] }).to eq(["default"])
    end
  end

  describe "GET /rails_table_preferences/preferences/:table_key/:name" do
    it "returns default settings when a preference does not exist" do
      get "/rails_table_preferences/preferences/orders/default"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        "table_key" => "orders",
        "name" => "default",
        "default" => false,
        "scope_type" => "owner",
        "editable" => true,
        "settings" => {
          "columns" => [],
          "filters" => {},
          "sorts" => []
        }
      )
    end

    it "resolves shared defaults when owner default does not exist" do
      RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [{ "key" => "shared_column" }] }
      )

      get "/rails_table_preferences/preferences/orders/default"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["scope_type"]).to eq("shared")
      expect(json["editable"]).to eq(false)
      expect(json["settings"]["columns"].first["key"]).to eq("shared_column")
    end

    it "prefers owner defaults over shared defaults" do
      RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [{ "key" => "shared_column" }] }
      )
      RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [{ "key" => "owner_column" }] }
      )

      get "/rails_table_preferences/preferences/orders/default"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["scope_type"]).to eq("owner")
      expect(json["settings"]["columns"].first["key"]).to eq("owner_column")
    end
  end

  describe "POST /rails_table_preferences/preferences/:table_key" do
    it "creates a named owner preference by default" do
      post "/rails_table_preferences/preferences/orders", params: {
        name: "inspection",
        settings: {
          columns: [
            {
              key: "customer_code",
              visible: true,
              order: "10"
            }
          ]
        }
      }

      expect(response).to have_http_status(:created)
      preference = RailsTablePreferences::Preference.find_for(user: user, table_key: "orders", name: "inspection")
      expect(preference).to be_present
      expect(preference.scope_type).to eq("owner")
      expect(preference.settings["columns"].first["key"]).to eq("customer_code")
    end

    it "rejects non-owner preference writes" do
      post "/rails_table_preferences/preferences/orders", params: {
        name: "team-default",
        scope_type: "shared",
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq(
        "error" => "owner_scope_required",
        "message" => "The mounted API only supports owner preset writes"
      )
      expect(
        RailsTablePreferences::Preference.find_for(
          user: user,
          table_key: "orders",
          name: "team-default",
          scope_type: "shared"
        )
      ).to be_nil
    end

    it "clears other default flags in the same scope when creating a new default" do
      existing = RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )

      post "/rails_table_preferences/preferences/orders", params: {
        name: "inspection",
        default: true,
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:created)
      expect(existing.reload.default_flag).to eq(false)
      expect(RailsTablePreferences::Preference.find_for(user: user, table_key: "orders", name: "inspection").default_flag).to eq(true)
    end

    it "clears other default flags with a configured owner foreign key" do
      original_preference_class = RailsTablePreferences.send(:remove_const, :Preference)
      RailsTablePreferences.configuration.owner_model = :members
      load File.expand_path("../../../app/models/rails_table_preferences/preference.rb", __dir__)

      member = Member.create!(name: "Member 1")
      other_member = Member.create!(name: "Member 2")
      Thread.current[:rails_table_preferences_current_user] = member

      existing = RailsTablePreferences::Preference.create!(
        user: member,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )
      other_owner_default = RailsTablePreferences::Preference.create!(
        user: other_member,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )

      post "/rails_table_preferences/preferences/orders", params: {
        name: "inspection",
        default: true,
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:created)
      expect(existing.reload.default_flag).to eq(false)
      expect(other_owner_default.reload.default_flag).to eq(true)
      expect(
        RailsTablePreferences::Preference.find_for(
          user: member,
          table_key: "orders",
          name: "inspection"
        ).default_flag
      ).to eq(true)
    ensure
      if defined?(original_preference_class) && original_preference_class
        RailsTablePreferences.send(:remove_const, :Preference) if RailsTablePreferences.const_defined?(:Preference, false)
        RailsTablePreferences.const_set(:Preference, original_preference_class)
      end
    end

    it "keeps the existing owner default when creating a new default fails" do
      existing = RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )
      failing_preference = RailsTablePreferences::Preference.new(
        user: user,
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] },
        default_flag: true
      )
      allow(RailsTablePreferences::Preference).to receive(:new).and_return(failing_preference)
      allow(failing_preference).to receive(:save!).and_raise(force_record_invalid(failing_preference))

      post "/rails_table_preferences/preferences/orders", params: {
        name: "inspection",
        default: true,
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(existing.reload.default_flag).to eq(true)
      expect(RailsTablePreferences::Preference.find_for(user: user, table_key: "orders", name: "inspection")).to be_nil
    end
  end

  describe "PATCH /rails_table_preferences/preferences/:table_key/:name" do
    it "creates a preference for the current user" do
      patch "/rails_table_preferences/preferences/orders/default", params: {
        settings: {
          columns: [
            {
              key: "customer_code",
              visible: false,
              order: "10",
              width: "120"
            }
          ]
        }
      }

      expect(response).to have_http_status(:ok)
      preference = RailsTablePreferences::Preference.find_for(user: user, table_key: "orders")
      expect(preference.settings["columns"]).to eq(
        [
          {
            "key" => "customer_code",
            "visible" => false,
            "order" => 10,
            "width" => 120,
            "pinned" => false
          }
        ]
      )
    end

    it "updates default flags for an existing preference" do
      existing = RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )
      target = RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] }
      )

      patch "/rails_table_preferences/preferences/orders/inspection", params: {
        default: true,
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:ok)
      expect(existing.reload.default_flag).to eq(false)
      expect(target.reload.default_flag).to eq(true)
    end

    it "rejects non-owner preference updates" do
      existing = RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [{ "key" => "original" }] }
      )

      patch "/rails_table_preferences/preferences/orders/inspection", params: {
        scope_type: "shared",
        default: true,
        settings: { columns: [{ key: "changed" }] }
      }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("owner_scope_required")
      expect(existing.reload.default_flag).to eq(false)
      expect(existing.settings["columns"].first["key"]).to eq("original")
    end

    it "rejects non-owner preference updates through PUT" do
      existing = RailsTablePreferences::Preference.create!(
        scope_type: "role",
        scope_key: "admin",
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [{ "key" => "original" }] }
      )

      put "/rails_table_preferences/preferences/orders/inspection", params: {
        scope_type: "role",
        scope_key: "admin",
        settings: { columns: [{ key: "changed" }] }
      }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("owner_scope_required")
      expect(existing.reload.settings["columns"].first["key"]).to eq("original")
    end
  end

  describe "DELETE /rails_table_preferences/preferences/:table_key/:name" do
    it "deletes a named preference" do
      RailsTablePreferences::Preference.create!(
        user: user,
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] }
      )

      delete "/rails_table_preferences/preferences/orders/inspection"

      expect(response).to have_http_status(:no_content)
      expect(RailsTablePreferences::Preference.find_for(user: user, table_key: "orders", name: "inspection")).to be_nil
    end

    it "rejects non-owner preference deletes" do
      existing = RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] }
      )

      delete "/rails_table_preferences/preferences/orders/inspection", params: { scope_type: "shared" }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("owner_scope_required")
      expect(existing.reload).to be_persisted
    end
  end
end

RSpec.describe "RailsTablePreferences::Preferences error contract", type: :request do
  let(:user) { User.create!(name: "User 1") }

  before do
    Thread.current[:rails_table_preferences_current_user] = user
  end

  it "returns a JSON validation error for duplicate preset names" do
    RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "inspection",
      settings: { "columns" => [] }
    )

    post "/rails_table_preferences/preferences/orders", params: {
      name: "inspection",
      settings: { columns: [] }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to include(
      "error" => "validation_failed",
      "message" => "Preference could not be saved"
    )
  end

  it "normalizes surrounding whitespace in preset names" do
    post "/rails_table_preferences/preferences/orders", params: {
      name: "  inspection  ",
      settings: { columns: [] }
    }

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)["name"]).to eq("inspection")
    expect(RailsTablePreferences::Preference.find_for(user: user, table_key: "orders", name: " inspection ")).to be_present
  end

  it "loads and normalizes an exact legacy whitespace name" do
    legacy = RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "legacy",
      settings: { "columns" => [{ "key" => "legacy_column" }] }
    )
    legacy.update_column(:name, " legacy inspection ")

    get "/rails_table_preferences/preferences/orders/%20legacy%20inspection%20"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
      "name" => " legacy inspection ",
      "settings" => include("columns" => [include("key" => "legacy_column")])
    )

    patch "/rails_table_preferences/preferences/orders/%20legacy%20inspection%20", params: {
      settings: { columns: [{ key: "updated_column" }] }
    }

    expect(response).to have_http_status(:ok)
    expect(legacy.reload.name).to eq("legacy inspection")
  end

  it "deletes an exact legacy whitespace name without orphaning it" do
    legacy = RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "remove-me",
      settings: { "columns" => [] }
    )
    legacy.update_column(:name, " remove me ")

    delete "/rails_table_preferences/preferences/orders/%20remove%20me%20"

    expect(response).to have_http_status(:no_content)
    expect(RailsTablePreferences::Preference.where(id: legacy.id)).not_to exist
  end

  it "returns validation failure instead of merging colliding legacy and normalized names" do
    normalized = RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "inspection",
      settings: { "columns" => [{ "key" => "normalized" }] }
    )
    legacy = RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "legacy",
      settings: { "columns" => [{ "key" => "legacy" }] }
    )
    legacy.update_column(:name, " inspection ")

    get "/rails_table_preferences/preferences/orders/%20inspection%20"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("settings", "columns", 0, "key")).to eq("legacy")

    patch "/rails_table_preferences/preferences/orders/%20inspection%20", params: { settings: { columns: [] } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to eq("validation_failed")
    expect(legacy.reload.name).to eq(" inspection ")
    expect(normalized.reload.name).to eq("inspection")
  end

  it "requires a current owner for owner preset writes" do
    Thread.current[:rails_table_preferences_current_user] = nil

    post "/rails_table_preferences/preferences/orders", params: {
      name: "inspection",
      settings: { columns: [] }
    }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq(
      "error" => "owner_required",
      "message" => "A current owner is required for owner preset writes"
    )
  end

  it "keeps shared presets readable without a current owner" do
    Thread.current[:rails_table_preferences_current_user] = nil
    RailsTablePreferences::Preference.create!(
      scope_type: "shared",
      table_key: "orders",
      name: "shared-view",
      settings: { "columns" => [] }
    )

    get "/rails_table_preferences/preferences/orders"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["preferences"].map { |preference| preference["name"] }).to eq(["shared-view"])
  end

  it "returns a JSON error when a destroy callback prevents deletion" do
    preference = RailsTablePreferences::Preference.create!(
      user: user,
      table_key: "orders",
      name: "inspection",
      settings: { "columns" => [] }
    )
    preference.errors.add(:base, "forced failure")
    allow(RailsTablePreferences::Preference).to receive(:find_for).and_return(preference)
    allow(preference).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new("forced failure", preference))

    delete "/rails_table_preferences/preferences/orders/inspection"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to include(
      "error" => "destroy_failed",
      "message" => "Preference could not be deleted"
    )
    expect(preference.reload).to be_persisted
  end

  it "keeps deleting a missing preset idempotent" do
    delete "/rails_table_preferences/preferences/orders/missing"

    expect(response).to have_http_status(:no_content)
  end
end