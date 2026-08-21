# frozen_string_literal: true

RSpec.describe "rails_table_preferences_controller.js" do
  let(:source_path) do
    File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__)
  end

  let(:source) { File.read(source_path).gsub(/\r\n?/, "\n") }

  it "defines status and read-only hint targets and defaults generated editor labels to Japanese" do
    expect(source).to include('static targets = ["editorRows", "presetName", "presetSelect", "defaultPreset", "status", "readOnlyHint"]')
    expect(source).to include('orderLabel: { type: String, default: "表示順" }')
    expect(source).to include('widthLabel: { type: String, default: "列幅" }')
    expect(source).to include('truncateLabel: { type: String, default: "省略文字数" }')
    expect(source).to include('dragLabel: { type: String, default: "ドラッグして並び替え" }')
    expect(source).to include('resizeLabel: { type: String, default: "列幅を変更" }')
    expect(source).to include('deleteConfirmLabel: { type: String, default: "この保存済み設定を削除します。よろしいですか？" }')
    expect(source).to include('readOnlyPresetHintLabel: { type: String, default: "この設定は直接上書きできません。保存すると個人用の新しい設定として保存されます。" }')
    expect(source).to include('loadingStatusLabel: { type: String, default: "設定を読み込み中です..." }')
    expect(source).to include('loadingFailedStatusLabel: { type: String, default: "設定の読み込みを完了できませんでした。" }')
    expect(source).to include('savingFailedStatusLabel: { type: String, default: "設定の保存を完了できませんでした。" }')
    expect(source).to include('savingAsNewFailedStatusLabel: { type: String, default: "新しい設定の保存を完了できませんでした。" }')
    expect(source).to include('deletingFailedStatusLabel: { type: String, default: "設定の削除を完了できませんでした。" }')
    expect(source).to include('operationFailedStatusLabel: { type: String, default: "設定の操作を完了できませんでした。" }')
  end

  it "defaults filter UI labels to Japanese" do
    expect(source).to include('filterLabel: { type: String, default: "絞り込み" }')
    expect(source).to include('filterApplyLabel: { type: String, default: "適用" }')
    expect(source).to include('filterClearLabel: { type: String, default: "クリア" }')
    expect(source).to include('filterOperatorLabel: { type: String, default: "条件" }')
    expect(source).to include('filterValueLabel: { type: String, default: "値" }')
    expect(source).to include('filterFromLabel: { type: String, default: "開始" }')
    expect(source).to include('filterToLabel: { type: String, default: "終了" }')
  end

  it "defaults sort UI labels to Japanese" do
    expect(source).to include('sortAscLabel: { type: String, default: "昇順" }')
    expect(source).to include('sortDescLabel: { type: String, default: "降順" }')
    expect(source).to include('sortClearLabel: { type: String, default: "並び替え解除" }')
  end

  it "restricts column display effects to the table element" do
    expect(source).to include("cellsFor(key)")
    expect(source).to include("const table = this.tableElement")
    expect(source).to include('return table.querySelectorAll(`[data-rails-table-preferences-column-key="${this.escapeSelectorValue(key)}"]`)')
    expect(source).to include("escapeSelectorValue(value)")
    expect(source).not_to include('return this.element.querySelectorAll(`[data-rails-table-preferences-column-key="${CSS.escape(key)}"]`)')
  end

  it "keeps a dedicated tableElement getter used by table operations" do
    expect(source).to include("get tableElement()")
    expect(source).to include('this.element.tagName === "TABLE" ? this.element : this.element.querySelector("table")')
    expect(source).to include("get headerCells()")
    expect(source).to include("get tableRows()")
  end

  it "preserves filters and sorts when editor rows are applied" do
    expect(source).to include("settingsFromEditor()")
    expect(source).to include("filters: this.settingsValue?.filters || {}")
    expect(source).to include("sorts: this.settingsValue?.sorts || []")
  end

  it "merges saved settings without letting stale column metadata override current definitions" do
    expect(source).to include("mergeSettings(defaultSettings, savedSettings)")
    expect(source).to include("label: defaultColumn.label")
    expect(source).to include("filter: defaultColumn.filter")
    expect(source).to include("sortable: defaultColumn.sortable")
    expect(source).to include("pinned: defaultColumn.pinned")
  end

  it "supports direct table header reordering" do
    expect(source).to include("installTableColumnDragHandles()")
    expect(source).to include("startTableColumnDrag(event)")
    expect(source).to include("dragTableColumnOver(event)")
    expect(source).to include("moveColumnInSettings(draggedKey, targetKey, placement)")
    expect(source).to include("reorderSensitivity")
  end

  it "does not start table dragging from header controls" do
    expect(source).to include("shouldIgnoreHeaderAction(target)")
    expect(source).to include('target.closest("[data-rails-table-preferences-filter-button]")')
    expect(source).to include('target.closest("[data-rails-table-preferences-resize-handle]")')
    expect(source).to include('target.closest("button")')
    expect(source).to include('target.closest("input")')
    expect(source).to include('target.closest("select")')
    expect(source).to include('target.closest("textarea")')
  end

  it "supports column resize with a widened pointer hit area" do
    expect(source).to include("resizeHandleWidth: { type: Number, default: 10 }")
    expect(source).to include("applyResizeHandleHitArea(cell, handle)")
    expect(source).to include("handle.style.width = `${this.normalizedResizeHandleWidth}px`")
    expect(source).to include('handle.style.touchAction = "none"')
    expect(source).to include('handle.addEventListener("pointerdown", this.startColumnResize.bind(this))')
    expect(source).to include("startColumnResize(event)")
    expect(source).to include("resizeColumn(event)")
    expect(source).not_to include('handle.addEventListener("mousedown", this.startColumnResize.bind(this))')
  end

  it "cleans up pointer resize listeners on completion, cancel, and disconnect" do
    expect(source).to include('document.addEventListener("pointermove", this.boundResizeColumn)')
    expect(source).to include('document.addEventListener("pointerup", this.boundStopColumnResize)')
    expect(source).to include('document.addEventListener("pointercancel", this.boundStopColumnResize)')
    expect(source).to include('document.removeEventListener("pointermove", this.boundResizeColumn)')
    expect(source).to include('document.removeEventListener("pointerup", this.boundStopColumnResize)')
    expect(source).to include('document.removeEventListener("pointercancel", this.boundStopColumnResize)')
    expect(source).not_to include('document.addEventListener("mousemove", this.boundResizeColumn)')
    expect(source).not_to include('document.addEventListener("mouseup", this.boundStopColumnResize)')
  end

  it "prefers user-facing column labels for resize handle accessible names" do
    expect(source).to include('handle.setAttribute("aria-label", this.resizeHandleLabel(cell))')
    expect(source).to include("resizeHandleLabel(cell)")
    expect(source).to include("visibleColumnLabelFor(cell, key)")
    expect(source).to include("headerCellTextLabel(cell)")
    expect(source).to include('const configuredLabel = this.columnDefinitionByKey(key)?.label || this.columnByKey(key)?.label')
    expect(source).to include('return headerText || key || ""')
    expect(source).not_to include('handle.setAttribute("aria-label", `${this.resizeLabelValue}: ${cell.dataset.railsTablePreferencesColumnKey}`)')
  end

  it "supports auto-fit from the resize handle with clamp and measurement helpers" do
    expect(source).to include("resizeAutoFitPadding: { type: Number, default: 24 }")
    expect(source).to include("resizeAutoFitMinWidth: { type: Number, default: 40 }")
    expect(source).to include("resizeAutoFitMaxWidth: { type: Number, default: 640 }")
    expect(source).to include('handle.addEventListener("dblclick", this.autoFitColumnFromHandle.bind(this))')
    expect(source).to include("autoFitColumnFromHandle(event)")
    expect(source).to include("autoFitWidthForColumn(key)")
    expect(source).to include("measureAutoFitCellWidth(cell)")
    expect(source).to include("cells.map((cell) => this.measureAutoFitCellWidth(cell))")
    expect(source).to include("Math.max(this.normalizedResizeAutoFitMinWidth, Math.min(this.normalizedResizeAutoFitMaxWidth, Math.ceil(measured)))")
  end

  it "keeps resize-handle auto-fit outside sort toggles and table drag starts" do
    expect(source).to include("autoFitColumnFromHandle(event) {\n    event.preventDefault()\n    event.stopPropagation()")
    expect(source).to include("if (this.shouldIgnoreHeaderAction(event.target)) return")
    expect(source).to include("if (this.shouldIgnoreHeaderAction(event.target)) {\n      event.preventDefault()\n      return\n    }")
  end

  it "installs filter buttons for filterable columns" do
    expect(source).to include("installFilterControls()")
    expect(source).to include("column?.filter")
    expect(source).to include('button.dataset.railsTablePreferencesFilterButton = "true"')
    expect(source).to include('button.setAttribute("aria-expanded", "false")')
    expect(source).to include("toggleFilterPanel(event, cell, column)")
  end

  it "summarizes active filter conditions for filter button labels" do
    expect(source).to include("filterButtonLabel(column, condition = {})")
    expect(source).to include("filterConditionSummary(condition = {})")
    expect(source).to include('return summary ? `${baseLabel} (${summary})` : baseLabel')
    expect(source).to include('button.setAttribute("aria-label", label)')
    expect(source).to include("button.title = label")
    expect(source).to include('if (operator === "between")')
    expect(source).to include('if (from && to) return `${operatorText}: ${from} - ${to}`')
    expect(source).to include('if (from) return `${operatorText}: ${this.filterFromLabelValue} ${from}`')
    expect(source).to include('if (to) return `${operatorText}: ${this.filterToLabelValue} ${to}`')
    expect(source).to include('if (["blank", "present", "true", "false"].includes(operator)) return operatorText')
    expect(source).to include('if (values.length > 0) return `${operatorText}: ${this.filterSummaryValues(values)}`')
    expect(source).to include('return value ? `${operatorText}: ${value}` : operatorText')
    expect(source).to include('return `${values.slice(0, 2).join(", ")} +${values.length - 2}`')
    expect(source).to include('return text.length > 24 ? `${text.slice(0, 21)}...` : text')
  end

  it "builds filter panels and stores neutral filter conditions" do
    expect(source).to include("filterPanelHtml(column)")
    expect(source).to include("filterValueHtml(filter, condition, selectedOperator)")
    expect(source).to include("applyFilterPanel(key, panel)")
    expect(source).to include("updateFilterCondition(key, condition)")
    expect(source).to include("filters: this.settingsValue?.filters || {}")
  end

  it "moves focus into the filter panel and supports escape dismissal" do
    expect(source).to include("focusInitialFilterPanelField(panel)")
    expect(source).to include("handleFilterPanelKeydown(event)")
    expect(source).to include('if (event.key !== "Escape") return')
    expect(source).to include("this.closeFilterPanel({ returnFocus: true })")
  end

  it "closes a body-mounted filter panel on outside click, scroll, and resize" do
    expect(source).to include("document.addEventListener(\"click\", this.boundCloseFilterPanel)")
    expect(source).to include("document.addEventListener(\"scroll\", this.boundCloseFilterPanelOnScroll, true)")
    expect(source).to include("window.addEventListener(\"resize\", this.boundCloseFilterPanelOnResize)")
    expect(source).to include("document.removeEventListener(\"scroll\", this.boundCloseFilterPanelOnScroll, true)")
    expect(source).to include("window.removeEventListener(\"resize\", this.boundCloseFilterPanelOnResize)")
  end

  it "keeps expanded state and controls wiring in sync with the open filter panel" do
    expect(source).to include("filterPanelId(columnKey)")
    expect(source).to include('button.setAttribute("aria-controls", panel.id)')
    expect(source).to include('button.setAttribute("aria-expanded", "true")')
    expect(source).to include('button.removeAttribute("aria-controls")')
  end

  it "supports common filter types and operators" do
    expect(source).to include('case "number"')
    expect(source).to include('case "date"')
    expect(source).to include('case "select"')
    expect(source).to include('case "boolean"')
    expect(source).to include('return ["contains", "equals", "starts_with", "ends_with", "blank", "present"]')
  end

  it "cleans up document-level listeners and detached panels" do
    expect(source).to include("disconnect()")
    expect(source).to include("uninstallDocumentResizeListeners()")
    expect(source).to include("closeFilterPanel()")
    expect(source).to include("document.removeEventListener")
  end

  it "supports sortable header click UI" do
    expect(source).to include("installSortControls()")
    expect(source).to include("toggleSortFromHeader(event, cell, column)")
    expect(source).to include("syncSortStates()")
    expect(source).to include("sortFor(key)")
    expect(source).to include('indicator.textContent = sort?.direction === "asc" ? "▲"')
    expect(source).to include('cell.setAttribute("aria-sort"')
  end

  it "limits sorting to sortable columns and ignores active drag/resize operations" do
    expect(source).to include("if (column?.sortable !== true) return")
    expect(source).to include("if (this.shouldIgnoreHeaderAction(event.target)) return")
    expect(source).to include("if (this.draggedTableColumnKey || this.resizingColumn) return")
  end

  it "applies pinned column classes, data attributes, and left offsets" do
    expect(source).to include("syncPinnedColumnOffsets()")
    expect(source).to include('cell.classList.toggle("rails-table-preferences-pinned", column.pinned === true)')
    expect(source).to include('cell.dataset.railsTablePreferencesPinned = "true"')
    expect(source).to include('cell.style.setProperty("--rails-table-preferences-pinned-left", `${left}px`)')
  end

  it "treats non-owner presets as read-only in the normal editor path" do
    expect(source).to include("currentPreferenceEditable")
    expect(source).to include("payload.editable !== false")
    expect(source).to include("syncPresetEditingState()")
    expect(source).to include("if (!this.currentPreferenceEditable) return this.createPresetFromEditor()")
    expect(source).to include("button.disabled = !editable")
    expect(source).to include("this.readOnlyHintTarget.hidden = !showReadOnlyHint")
  end

  it "confirms editable preset deletion before issuing DELETE" do
    expect(source).to include("if (!this.confirmDeletePreset()) return")
    expect(source).to include("confirmDeletePreset()")
    expect(source).to include("const message = this.deleteConfirmLabelValue?.trim()")
    expect(source).to include("return window.confirm(message)")
  end

  it "updates a live status region and temporary busy state around async preset actions" do
    expect(source).to include("this.refreshPresetOptionsOnConnect()")
    expect(source).to include("withBusyStatus(callback,")
    expect(source).to include("setBusyState(busy)")
    expect(source).to include("setStatus(message)")
    expect(source).to include('this.element.querySelectorAll(".rails-table-preferences-editor__actions button")')
    expect(source).to include('if (this.busy) this.element.setAttribute("aria-busy", "true")')
    expect(source).to include('else this.element.removeAttribute("aria-busy")')
    expect(source).to include("errorLabel: this.loadingFailedStatusLabelValue")
    expect(source).to include("errorLabel: this.savingFailedStatusLabelValue")
    expect(source).to include("errorLabel: this.savingAsNewFailedStatusLabelValue")
    expect(source).to include("errorLabel: this.deletingFailedStatusLabelValue")
    expect(source).to include("console.error(error)")
  end

  it "guards generated editor inputs and bundled table controls while busy" do
    expect(source).to include("setEditorRowsBusyState(busy)")
    expect(source).to include('this.editorRowsTarget.querySelectorAll("input, button, select, textarea")')
    expect(source).to include("setTableInteractionBusyState(busy)")
    expect(source).to include('table.querySelectorAll("[data-rails-table-preferences-filter-button], [data-rails-table-preferences-resize-handle]")')
    expect(source).to include('if (cell.dataset.railsTablePreferencesTableDragInstalled === "true") cell.draggable = !busy')
    expect(source).to include('if (this.busy) this.closeFilterPanel()')
  end

  it "ignores bundled drag, filter, sort, and resize interactions while busy" do
    expect(source).to include("dragEditorRowStart(event) {\n    if (this.busy) {\n      event.preventDefault()\n      return\n    }")
    expect(source).to include("startTableColumnDrag(event) {\n    if (this.busy) {\n      event.preventDefault()\n      return\n    }")
    expect(source).to include("startColumnResize(event) {\n    if (event.button !== undefined && event.button !== 0) return\n    event.preventDefault()\n    event.stopPropagation()\n    if (this.busy) return")
    expect(source).to include("if (this.busy || !this.resizingColumn) return")
    expect(source).to include("toggleFilterPanel(event, headerCell, column) {\n    if (this.busy) return")
    expect(source).to include("applyFilterPanel(key, panel) {\n    if (this.busy) return")
    expect(source).to include("clearFilter(key) {\n    if (this.busy) return")
    expect(source).to include("toggleSortFromHeader(event, cell, column) {\n    if (this.busy) return")
  end

  it "labels preset options with localized scope fallbacks and scope metadata" do
    expect(source).to include("buildPresetOption(preset)")
    expect(source).to include('const scopeType = preset.scope_type || "owner"')
    expect(source).to include("const scopeLabel = preset.scope_label || this.scopeFallbackLabel(scopeType)")
    expect(source).to include('const scopeMark = scopeType !== "owner" && scopeLabel ? ` [${scopeLabel}]` : ""')
    expect(source).to include("scopeFallbackLabel(scopeType)")
    expect(source).to include('case "shared": return this.scopeSharedLabelValue')
    expect(source).to include('case "role": return this.scopeRoleLabelValue')
    expect(source).to include('case "organization": return this.scopeOrganizationLabelValue')
    expect(source).to include('option.dataset.scopeType = scopeType')
    expect(source).to include('option.dataset.editable = preset.editable === false ? "false" : "true"')
  end
end