# frozen_string_literal: true

require "spec_helper"

RSpec.describe "package editor metadata contract" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:package_controller_source) { File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js")) }
  let(:editor_partial_source) { File.read(File.join(repo_root, "app/views/rails_table_preferences/_editor.html.erb")) }

  it "keeps editor row changes merged with the current column metadata" do
    expect(package_controller_source).to include("editorIdPrefix: String")
    expect(package_controller_source).to include("settingsFromEditor()")
    expect(package_controller_source).to include("const editorSettings = super.settingsFromEditor()")
    expect(package_controller_source).to include("this.defaultSettings ? this.mergeSettings(this.defaultSettings, editorSettings) : editorSettings")
  end

  it "namespaces package filter panel ids by an explicit editor instance or the base controller instance" do
    expect(package_controller_source).to include("filterPanelId(columnKey)")
    expect(package_controller_source).to include("if (!this.editorIdPrefixValue) return super.filterPanelId(columnKey)")
    expect(package_controller_source).to include('if (this.editorIdPrefixValue) return this.filterPanelIdSegment(this.editorIdPrefixValue, "table")')
    expect(package_controller_source).to include('`${this.filterPanelIdSegment(this.tableKeyValue, "table")}-${this.filterPanelInstanceId}`')
    expect(editor_partial_source).to include("data-rails-table-preferences-editor-id-prefix-value=\"<%= editor_id_prefix %>\"")
  end
end
