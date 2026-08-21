# frozen_string_literal: true

RSpec.describe RailsTablePreferences::Resolver do
  let(:owner) { instance_double("User", id: 1) }

  describe ".preference" do
    it "resolves an explicitly named available preference" do
      preference = instance_double(RailsTablePreferences::Preference)
      allow(RailsTablePreferences::Preference).to receive(:available_named_preference).and_return(preference)

      expect(
        described_class.preference(
          owner: owner,
          table_key: :orders,
          name: :inspection,
          scope_context: { roles: ["admin"] }
        )
      ).to eq(preference)

      expect(RailsTablePreferences::Preference).to have_received(:available_named_preference).with(
        user: owner,
        table_key: :orders,
        name: :inspection,
        scope_context: { roles: ["admin"] }
      )
    end

    it "uses scoped default resolution when no name is given" do
      preference = instance_double(RailsTablePreferences::Preference)
      allow(RailsTablePreferences::Preference).to receive(:default_for).and_return(preference)

      expect(described_class.preference(owner: owner, table_key: :orders)).to eq(preference)
      expect(RailsTablePreferences::Preference).to have_received(:default_for).with(
        user: owner,
        table_key: :orders,
        scope_context: {}
      )
    end

    it "returns nil without an owner" do
      expect(described_class.preference(owner: nil, table_key: :orders)).to be_nil
    end
  end

  describe ".settings" do
    it "normalizes resolved settings" do
      preference = instance_double(
        RailsTablePreferences::Preference,
        settings: {
          filters: { customer_name: { operator: :contains, value: "Yamada" } },
          sorts: [{ key: :delivery_date, direction: :DESC }]
        }
      )
      allow(RailsTablePreferences::Preference).to receive(:available_named_preference).and_return(preference)

      expect(described_class.settings(owner: owner, table_key: :orders, name: :inspection)).to eq(
        "columns" => [],
        "filters" => { "customer_name" => { "operator" => "contains", "value" => "Yamada" } },
        "sorts" => [{ "key" => "delivery_date", "direction" => "desc" }]
      )
    end

    it "normalizes fallback settings when no preference is resolved" do
      allow(RailsTablePreferences::Preference).to receive(:default_for).and_return(nil)

      expect(
        described_class.settings(
          owner: owner,
          table_key: :orders,
          fallback: { filters: { status: { operator: :equals, value: "pending" } } }
        )
      ).to eq(
        "columns" => [],
        "filters" => { "status" => { "operator" => "equals", "value" => "pending" } },
        "sorts" => []
      )
    end
  end

  describe "public module API" do
    it "exposes controller-independent preference resolution" do
      allow(described_class).to receive(:preference).and_return(:resolved)

      expect(RailsTablePreferences.resolve_preference(owner: owner, table_key: :orders)).to eq(:resolved)
      expect(described_class).to have_received(:preference).with(
        owner: owner,
        table_key: :orders,
        name: nil,
        scope_context: {}
      )
    end
  end
end
