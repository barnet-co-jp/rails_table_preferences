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

    it "creates a shared preference when requested" do
      post "/rails_table_preferences/preferences/orders", params: {
        name: "team-default",
        scope_type: "shared",
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:created)
      preference = RailsTablePreferences::Preference.find_for(
        user: user,
        table_key: "orders",
        name: "team-default",
        scope_type: "shared"
      )
      expect(preference).to be_present
      expect(preference.user).to be_nil
      expect(preference.scope_type).to eq("shared")
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

      expect(response).to have_http_status(:internal_server_error)
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

    it "keeps the existing shared default when updating a shared default fails" do
      existing = RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "default",
        default_flag: true,
        settings: { "columns" => [] }
      )
      target = RailsTablePreferences::Preference.create!(
        scope_type: "shared",
        table_key: "orders",
        name: "inspection",
        settings: { "columns" => [] }
      )
      allow(RailsTablePreferences::Preference).to receive(:find_or_initialize_for).and_return(target)
      allow(target).to receive(:save!).and_raise(force_record_invalid(target))

      patch "/rails_table_preferences/preferences/orders/inspection", params: {
        scope_type: "shared",
        default: true,
        settings: { columns: [] }
      }

      expect(response).to have_http_status(:internal_server_error)
      expect(existing.reload.default_flag).to eq(true)
      expect(target.reload.default_flag).to eq(false)
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
  end
end
