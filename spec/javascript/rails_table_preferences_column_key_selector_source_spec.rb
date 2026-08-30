# frozen_string_literal: true

RSpec.describe "column key selector boundary" do
  let(:controller_source_path) do
    File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__)
  end

  let(:docs_path) do
    File.expand_path("../../docs/column_key_contract.md", __dir__)
  end

  let(:controller_source) { File.read(controller_source_path) }
  let(:docs) { File.read(docs_path) }

  it "keeps cell lookup scoped to actual table cells and escapes column keys before building the selector" do
    expect(controller_source).to include("cellsFor(key)")
    expect(controller_source).to include("const table = this.tableElement")
    expect(controller_source).to include("const escapedKey = this.escapeSelectorValue(key)")
    expect(controller_source).to include('th[data-rails-table-preferences-column-key="${escapedKey}"], td[data-rails-table-preferences-column-key="${escapedKey}"]')
    expect(controller_source).not_to include('return table.querySelectorAll(`[data-rails-table-preferences-column-key="${this.escapeSelectorValue(key)}"]`)')
    expect(controller_source).to include("escapeSelectorValue(value)")
  end

  it "documents CSS.escape coverage and the narrow fallback boundary for special column keys" do
    expect(controller_source).to include("CSS.escape(String(value))")
    expect(controller_source).to include("return String(value).replace(")
    expect(controller_source).to include("$&")

    expect(docs).to include("customer.name")
    expect(docs).to include("customer:id")
    expect(docs).to include("status]flag")
    expect(docs).to include("quotes or backslashes")
    expect(docs).to include("without `CSS.escape`")
    expect(docs).to include("avoid newline and control characters")
    expect(docs).to include("without changing the saved settings schema")
  end
end
