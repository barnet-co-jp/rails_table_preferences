# frozen_string_literal: true

RSpec.describe "rails_table_preferences backlog hardening" do
  let(:base_source) do
    File.read(File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__))
  end
  let(:package_source) do
    File.read(File.expand_path("../../app/javascript/rails_table_preferences/controller.js", __dir__))
  end
  let(:stylesheet) do
    File.read(File.expand_path("../../app/assets/stylesheets/rails_table_preferences.css", __dir__))
  end

  it "keeps filter panel ids unique across controller instances and normalization collisions" do
    expect(base_source).to include("this.filterPanelInstanceId ||= ++filterPanelInstanceSequence")
    expect(base_source).to include("const encoded = encodeURIComponent(text)")
    expect(base_source).to include('return `${encoded.length}_${encoded}`')
    expect(base_source).not_to include('replace(/%/g, "_")')
    expect(base_source).to include('${tableKey}-${this.filterPanelInstanceId}-${normalizedColumnKey}')
    expect(package_source).to include("if (!this.editorIdPrefixValue) return super.filterPanelId(columnKey)")
  end

  it "supports keyboard and additive sortable-header interactions without aria-sort on static headers" do
    expect(base_source).to include('cell.addEventListener("keydown"')
    expect(base_source).to include('["Enter", " ", "Spacebar"].includes(event.key)')
    expect(base_source).to include("if (!event.shiftKey)")
    expect(base_source).to include("sorts.map((sort, index)")
    expect(base_source).to include("sortIndex === 0")
    expect(base_source).to include('cell.setAttribute("aria-description"')
    expect(base_source).to include('cell.removeAttribute("aria-sort")')
  end

  it "returns focus after filter actions and prevents stale auto-generated titles" do
    expect(base_source.scan("this.closeFilterPanel({ returnFocus: true })").length).to be >= 3
    expect(base_source).to include('cell.dataset.railsTablePreferencesAutoTitle === "true"')
    expect(base_source).to include('cell.dataset.railsTablePreferencesAutoTitle = "true"')
  end

  it "guards async DOM updates after disconnect and distinguishes partial success" do
    expect(base_source).to include("lifecycleActive(generation)")
    expect(base_source).to include("refreshPresetOptionsAfterMutation(generation)")
    expect(base_source).to include("this.partialSuccess = { generation, message: this.presetListRefreshFailedStatusLabelValue }")
    expect(base_source).to include("this.partialSuccess?.generation === generation")
    expect(package_source).to include('this.setStatus(partialSuccessMessage, "warning")')
  end

  it "uses semantic editor field classes instead of label position selectors" do
    expect(base_source).to include('class="rails-table-preferences-editor__order"')
    expect(base_source).to include('class="rails-table-preferences-editor__width"')
    expect(base_source).to include('class="rails-table-preferences-editor__truncate"')
    expect(stylesheet).not_to include("nth-of-type")
  end
end
