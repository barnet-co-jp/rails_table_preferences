# frozen_string_literal: true

require "spec_helper"

RSpec.describe "package entrypoint controller source" do
  let(:controller_source_path) do
    File.expand_path("../app/javascript/rails_table_preferences/controller.js", __dir__)
  end

  let(:base_controller_source_path) do
    File.expand_path("../app/javascript/controllers/rails_table_preferences_controller.js", __dir__)
  end

  let(:controller_declaration_path) do
    File.expand_path("../app/javascript/rails_table_preferences/controller.d.ts", __dir__)
  end

  let(:index_declaration_path) do
    File.expand_path("../app/javascript/rails_table_preferences/index.d.ts", __dir__)
  end

  let(:controller_source) { File.read(controller_source_path).gsub(/\r\n?/, "\n") }
  let(:base_controller_source) { File.read(base_controller_source_path).gsub(/\r\n?/, "\n") }
  let(:controller_declaration) { File.read(controller_declaration_path) }
  let(:index_declaration) { File.read(index_declaration_path) }

  it "keeps filterValueHtml as a single package entrypoint override" do
    expect(controller_source.scan(/\n\s+filterValueHtml\(filter, condition, selectedOperator\) \{/).size).to eq(1)
    expect(controller_source).to include("return super.filterValueHtml(filter, condition, selectedOperator)")
  end

  it "keeps select filters on the option-search source of truth" do
    expect(controller_source).to include("const value = this.selectFilterOptionValue(option)")
    expect(controller_source).to include("const label = this.selectFilterOptionLabel(option, value)")
    expect(controller_source).to include("${this.selectFilterOptionSearchHtml(filter.options)}<select data-field=\"values\" multiple>")
    expect(controller_source).to include("selectFilterOptionSearchThreshold: { type: Number, default: 8 }")
    expect(controller_source).to include("if (!Array.isArray(options) || options.length === 0 || options.length < this.selectFilterOptionSearchThreshold) return \"\"")
    expect(controller_source).to include('data-rails-table-preferences-option-search-empty role="status" aria-live="polite" aria-atomic="true" hidden')
    expect(controller_source).to include("const threshold = Number(this.selectFilterOptionSearchThresholdValue)")
    expect(controller_source).to include("if (!Number.isFinite(threshold)) return 8")
    expect(controller_source).to include("return Math.floor(threshold)")
  end

  it "keeps select option search empty state tied to all matching options" do
    expect(controller_source).to include("let matchingOptions = 0")
    expect(controller_source).to include("if (matchesQuery) matchingOptions += 1")
    expect(controller_source).to include("option.hidden = Boolean(query) && !option.selected && !matchesQuery")
    expect(controller_source).to include("emptyMessage.hidden = !query || matchingOptions > 0")
    expect(controller_source).not_to include("matchingUnselectedOptions")
  end

  it "keeps datetime and time browser attributes scoped to packaged filter inputs" do
    expect(controller_source).to include('const DATE_TIME_FILTER_TYPES = new Set(["datetime", "datetime-local", "time"])')
    expect(controller_source).to include("if ([\"number\", \"date\"].includes(this.filterInputType(filter)) || DATE_TIME_FILTER_TYPES.has(String(filter.type)))")
    expect(controller_source).to include('attributes.push(this.filterInputAttribute("min", filter.min))')
    expect(controller_source).to include('attributes.push(this.filterInputAttribute("max", filter.max))')
    expect(controller_source).to include('attributes.push(this.filterInputAttribute("step", filter.step))')
    expect(controller_source).to include('["text", "number", "date", "datetime-local", "time"].includes(inputType)')
    expect(controller_source).to include('data-field="from" value="${this.escapeHtml(condition.from ?? "")}"${fromAttributes}')
    expect(controller_source).to include('data-field="to" value="${this.escapeHtml(condition.to ?? "")}"${toAttributes}')
    expect(controller_source).to include('data-field="value" value="${this.escapeHtml(condition.value ?? "")}"${attributes}')
    expect(base_controller_source).not_to include("DATE_TIME_FILTER_TYPES")
  end

  it "keeps visibility bulk actions scoped to all editor rows" do
    bulk_visibility_body = controller_source.match(/\n\s+setEditorColumnVisibility\(event, visible\) \{(?<body>.*?)\n\s+\}\n\n\s+buildEditorMoveControls/m)&.[](:body)

    expect(bulk_visibility_body).not_to be_nil
    expect(bulk_visibility_body).to include("this.editorRows.forEach((row) => {")
    expect(bulk_visibility_body).not_to include("this.editorRowsForMovement")
    expect(bulk_visibility_body).not_to include("!row.hidden")
  end

  it "keeps visibility bulk actions on the existing status feedback surface" do
    bulk_visibility_body = controller_source.match(/\n\s+setEditorColumnVisibility\(event, visible\) \{(?<body>.*?)\n\s+\}\n\n\s+buildEditorMoveControls/m)&.[](:body)

    expect(bulk_visibility_body).not_to be_nil
    expect(controller_source).to include("visibilityBulkHiddenStatusLabel: { type: String")
    expect(controller_source).to include("visibilityBulkShownStatusLabel: { type: String")
    expect(bulk_visibility_body).to include("this.setStatus(visible ? this.visibilityBulkShownStatusLabelValue : this.visibilityBulkHiddenStatusLabelValue, \"success\")")
  end

  it "keeps reset as a packaged success lifecycle action" do
    expect(controller_source).to include('this.dispatchPreferenceEvent("applied", { action: "reset" })')
    expect(controller_declaration).to include('export type RailsTablePreferencesSuccessAction = "apply" | "reset" | "save" | "create" | "load" | "delete"')
    expect(index_declaration).to include("RailsTablePreferencesSuccessAction")
  end

  it "keeps lifecycle success events on the current settings snapshot" do
    expect(controller_source).to include("preferenceEventDetail(detail = {}) {")
    expect(controller_source).to include("tableKey: this.tableKeyValue")
    expect(controller_source).to include("name: this.currentPresetName")
    expect(controller_source).to include("settings: this.settingsSnapshot(this.settingsValue)")
    expect(controller_source).to include("settingsSnapshot(settings) {")
    expect(controller_source).to include('if (typeof structuredClone === "function") return structuredClone(settings)')
    expect(controller_source).to include('this.dispatchPreferenceEvent("saved", { action: "save" })')
    expect(controller_source).to include('this.dispatchPreferenceEvent("saved", { action: "create" })')
    expect(controller_source).to include('this.dispatchPreferenceEvent("loaded", { action: "load" })')
    expect(controller_source).to include('this.dispatchPreferenceEvent("applied", { action: "clear-filters-and-sorts" })')
  end

  it "keeps deleted lifecycle events on the deleted name and post-delete default settings" do
    delete_body = controller_source.match(/\n\s+async deletePreset\(event\) \{(?<body>.*?)\n\s+\}\n\n\s+async refreshPresetOptionsOnConnect/m)&.[](:body)

    expect(delete_body).not_to be_nil
    expect(delete_body).to include("const deletedName = this.currentPresetName")
    expect(delete_body).to include('this.nameValue = "default"')
    expect(delete_body).to include('this.urlValue = this.preferenceUrl("default")')
    expect(delete_body).to include("this.settingsValue = this.defaultSettings")
    expect(delete_body).to include("this.apply()")
    expect(delete_body).to include('this.dispatchPreferenceEvent("deleted", { action: "delete", name: deletedName })')
  end

  it "keeps editor search as a package entrypoint-only visibility filter" do
    expect(controller_source).to include("this.ensureEditorSearchControl()")
    expect(controller_source).to include("this.syncEditorSearchResults()")
    expect(controller_source).to include("row.hidden = hidden")
    expect(controller_source).to include("if (this.editorSearchEmptyMessage) this.editorSearchEmptyMessage.hidden = !query || visibleCount > 0")
    expect(base_controller_source).not_to include("ensureEditorSearchControl")
    expect(base_controller_source).not_to include("syncEditorSearchResults")
  end

  it "keeps editor search group metadata explicit and avoids object string leakage" do
    expect(controller_source).to include("row.dataset.railsTablePreferencesEditorSearchText = this.editorSearchTextForColumn(column)")
    expect(controller_source).to include("editorSearchTextForColumn(column) {")
    expect(controller_source).to include("...this.editorSearchGroupTokens(column.group)")
    expect(controller_source).to include("editorSearchGroupTokens(group) {")
    expect(controller_source).to include("if (typeof group === \"object\") return [group.key, group.label].filter(Boolean)")
    expect(controller_source).not_to include("[column.label, column.key, column.group].filter(Boolean).join")
  end

  it "keeps editor search no-results as a polite status cue" do
    expect(controller_source).to include('empty.setAttribute("role", "status")')
    expect(controller_source).to include('empty.setAttribute("aria-live", "polite")')
    expect(controller_source).to include('empty.setAttribute("aria-atomic", "true")')
    expect(controller_source).to include("empty.hidden = true")
  end

  it "keeps hidden editor rows in apply/save settings while moves use visible rows" do
    expect(base_controller_source).to include("const columns = this.editorRows.map((row, index) => {")
    expect(controller_source).to include("const visibleRows = this.editorRows.filter((row) => !row.hidden)")
    expect(controller_source).to include("return visibleRows.length > 0 ? visibleRows : this.editorRows")
    expect(controller_source).to include("button.disabled = this.busy || row.hidden || index < 0 || (direction === \"up\" ? index === 0 : index === rows.length - 1)")
  end

  it "keeps saved presets merged on top of current column definitions" do
    expect(base_controller_source).to include("columns: this.columnsValue.map((column, index) => ({ key: column.key, label: column.label || column.key, visible: column.visible !== false, order: column.order ?? (index + 1) * 10, width: column.width, truncate: column.truncate, overflow: column.overflow, pinned: column.pinned === true, filter: column.filter, sortable: column.sortable }))")
    expect(base_controller_source).to include("const savedColumns = new Map((savedSettings?.columns || []).map((column) => [column.key, column]))")
    expect(base_controller_source).to include("const columns = defaultSettings.columns.map((defaultColumn, index) => {")
    expect(base_controller_source).to include("const savedColumn = savedColumns.get(defaultColumn.key) || {}")
    expect(base_controller_source).to include("return { ...defaultColumn, ...savedColumn, label: defaultColumn.label, filter: defaultColumn.filter, sortable: defaultColumn.sortable, overflow: defaultColumn.overflow, pinned: defaultColumn.pinned, order: savedColumn.order ?? defaultColumn.order ?? (index + 1) * 10, visible: savedColumn.visible ?? defaultColumn.visible }")
  end

  it "keeps the package editor drag handle visual-only while real reorder controls stay keyboard reachable" do
    expect(controller_source).to include("this.replaceEditorDragHandle(row)")
    expect(controller_source).to include("replaceEditorDragHandle(row)")
    expect(controller_source).to include('visualHandle.dataset.railsTablePreferencesEditorDragHandle = "visual"')
    expect(controller_source).to include('visualHandle.setAttribute("aria-hidden", "true")')
    expect(controller_source).to include("handle.replaceWith(visualHandle)")
    expect(controller_source).to include("this.buildEditorMoveControls()")
    expect(base_controller_source).to include('<button type="button" class="rails-table-preferences-editor__drag-handle"')
  end

  it "keeps the status-state hook scoped to packaged status feedback" do
    expect(controller_source).to include('this.statusState = "idle"')
    expect(controller_source).to include('target.setAttribute("data-rails-table-preferences-status-state", state || "idle")')
    expect(controller_source).to include('if (busyLabel) this.setStatus(busyLabel, "busy")')
    expect(controller_source).to include('if (successLabel) this.setStatus(successLabel, "success")')
    expect(controller_source).to include('if (this.statusState === "success") this.setStatus("")')
    expect(controller_source).to include('this.statusState = "error"')
    expect(controller_source).to include('this.syncStatusStateHook("error")')
    expect(base_controller_source).not_to include("data-rails-table-preferences-status-state")
  end
end
