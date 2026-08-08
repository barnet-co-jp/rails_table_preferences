import RailsTablePreferencesBaseController from "../controllers/rails_table_preferences_controller"

const DATE_TIME_FILTER_TYPES = new Set(["datetime", "datetime-local", "time"])

export default class RailsTablePreferencesController extends RailsTablePreferencesBaseController {
  static targets = [...(RailsTablePreferencesBaseController.targets || []), "dirtyState"]

  static values = {
    ...RailsTablePreferencesBaseController.values,
    editorIdPrefix: String,
    filterOperatorLabels: { type: Object, default: {} },
    selectFilterOptionSearchLabel: { type: String, default: "候補を絞り込み" },
    selectFilterOptionSearchPlaceholder: { type: String, default: "候補を絞り込み" },
    editorSearchLabel: { type: String, default: "列を検索" },
    editorSearchPlaceholder: { type: String, default: "列名で絞り込み" },
    editorNoSearchResultsLabel: { type: String, default: "一致する列はありません。検索語を変更してください。" },
    visibilityBulkHiddenStatusLabel: { type: String, default: "すべての列を非表示にしました。全列表示で戻せます。" },
    visibilityBulkShownStatusLabel: { type: String, default: "すべての列を表示しました。" },
    moveUpLabel: { type: String, default: "上へ移動" },
    moveDownLabel: { type: String, default: "下へ移動" },
    dirtyStateLabel: { type: String, default: "未保存の変更があります。" },
    resizeAutoFitStatusLabel: { type: String, default: "列幅を自動調整しました。" },
    resetStatusLabel: { type: String, default: "テーブル初期設定に戻しました。" },
    selectFilterOptionSearchThreshold: { type: Number, default: 8 },
    presetSearchLabel: { type: String, default: "保存済み設定を検索" },
    presetSearchPlaceholder: { type: String, default: "設定名やスコープで絞り込み" },
    presetNoSearchResultsLabel: { type: String, default: "一致する保存済み設定はありません。検索語を変更するか、検索欄を空にすると候補に戻ります。" },
    presetSearchThreshold: { type: Number, default: 8 }
  }

  buildPresetOption(preset) {
    const option = super.buildPresetOption(preset)
    const name = preset.name || "default"
    const scopeType = preset.scope_type || "owner"
    const scopeLabel = preset.scope_label || this.scopeFallbackLabel(scopeType)
    const defaultMark = preset.default === true ? "（既定）"
      : ""
    const scopeMark = scopeLabel ? ` [${scopeLabel}]` : ""
    option.textContent = `${name}${scopeMark}${defaultMark}`
    return option
  }

  renderPresetOptions() {
    if (!this.hasPresetSelectTarget) return

    this.ensurePresetSearchControl()

    const allPresets = this.presets.length ? this.presets : [{ name: this.currentPresetName, default: false, editable: true }]
    const shouldShowSearch = allPresets.length >= this.normalizedPresetSearchThreshold
    if (!shouldShowSearch && this.presetSearchInput) this.presetSearchInput.value = ""

    const query = shouldShowSearch ? this.presetSearchQuery : ""
    const visiblePresets = query ? allPresets.filter((preset) => this.presetMatchesSearch(preset, query)) : allPresets

    this.presetSelectTarget.innerHTML = ""
    if (visiblePresets.length > 0) this.appendPresetOptions(visiblePresets)

    this.syncPresetSelectValue(visiblePresets)
    this.syncPresetSearchState({ query, visibleCount: visiblePresets.length, enabled: shouldShowSearch })
    this.syncDeletePresetButtonContext()
  }

  appendPresetOptions(presets) {
    const groups = this.groupPresetsForSelect(presets)
    if (groups.length <= 1) {
      presets.forEach((preset) => this.presetSelectTarget.appendChild(this.buildPresetOption(preset)))
      return
    }

    groups.forEach((group) => {
      const optgroup = document.createElement("optgroup")
      optgroup.label = group.label
      group.presets.forEach((preset) => optgroup.appendChild(this.buildPresetOption(preset)))
      this.presetSelectTarget.appendChild(optgroup)
    })
  }

  syncPresetSelectValue(visiblePresets) {
    const currentPresetVisible = visiblePresets.some((preset) => (preset.name || "default") === this.currentPresetName)
    if (currentPresetVisible) {
      this.presetSelectTarget.value = this.currentPresetName
      return
    }

    if (this.presetSelectTarget.options.length > 0) {
      this.presetSelectTarget.selectedIndex = -1
    }
  }

  ensurePresetSearchControl() {
    if (this.presetSearchControl || !this.hasPresetSelectTarget) return

    const wrapper = document.createElement("div")
    wrapper.className = "rails-table-preferences-editor__preset-search"
    wrapper.dataset.railsTablePreferencesPresetSearch = "true"

    const label = document.createElement("label")
    label.className = "rails-table-preferences-editor__search"
    const labelText = document.createElement("span")
    labelText.textContent = this.presetSearchLabelValue
    const input = document.createElement("input")
    input.type = "search"
    input.placeholder = this.presetSearchPlaceholderValue
    input.setAttribute("aria-label", this.presetSearchLabelValue)
    input.dataset.railsTablePreferencesPresetSearchInput = "true"
    input.addEventListener("input", () => this.renderPresetOptions())
    label.append(labelText, input)

    const empty = document.createElement("p")
    empty.className = "rails-table-preferences-editor__search-empty"
    empty.dataset.railsTablePreferencesPresetSearchEmpty = "true"
    empty.hidden = true
    empty.textContent = this.presetNoSearchResultsLabelValue

    wrapper.append(label, empty)
    this.presetSelectTarget.before(wrapper)
  }

  syncPresetSearchState({ query, visibleCount, enabled }) {
    if (this.presetSearchControl) this.presetSearchControl.hidden = !enabled
    if (this.presetSearchInput) this.presetSearchInput.disabled = this.busy || !enabled
    if (this.presetSearchEmptyMessage) this.presetSearchEmptyMessage.hidden = !enabled || !query || visibleCount > 0
    if (this.hasPresetSelectTarget) this.presetSelectTarget.disabled = this.busy || (enabled && Boolean(query) && visibleCount === 0)
  }

  setBusyState(busy) {
    super.setBusyState(busy)
    this.syncPresetSearchState({
      query: this.presetSearchQuery,
      visibleCount: this.visiblePresetOptionCount,
      enabled: !this.presetSearchControl?.hidden
    })
  }

  presetMatchesSearch(preset, query) {
    return this.presetSearchText(preset).includes(query)
  }

  presetSearchText(preset) {
    const scopeType = preset.scope_type || "owner"
    const scopeLabel = preset.scope_label || this.scopeFallbackLabel(scopeType)
    return [preset.name || "default", scopeLabel, scopeType]
      .filter(Boolean)
      .join(" ")
      .toLocaleLowerCase()
  }

  get presetSearchControl() {
    return this.element.querySelector("[data-rails-table-preferences-preset-search]")
  }

  get presetSearchInput() {
    return this.presetSearchControl?.querySelector("[data-rails-table-preferences-preset-search-input]")
  }

  get presetSearchEmptyMessage() {
    return this.presetSearchControl?.querySelector("[data-rails-table-preferences-preset-search-empty]")
  }

  get presetSearchQuery() {
    return String(this.presetSearchInput?.value || "").trim().toLocaleLowerCase()
  }

  get visiblePresetOptionCount() {
    return this.presetSelectTarget?.querySelectorAll("option").length || 0
  }

  get normalizedPresetSearchThreshold() {
    const rawValue = this.element?.dataset?.railsTablePreferencesPresetSearchThresholdValue
    if (rawValue !== undefined && String(rawValue).trim() === "") return 8

    const threshold = Number(this.presetSearchThresholdValue)
    if (!Number.isFinite(threshold)) return 8
    return Math.max(0, Math.floor(threshold))
  }

  settingsFromEditor() {
    const editorSettings = super.settingsFromEditor()
    if (!this.hasEditorRowsTarget) {
      return this.defaultSettings ? this.mergeSettings(this.defaultSettings, editorSettings) : editorSettings
    }

    const columns = this.editorRows.map((row, index) => {
      const key = row.dataset.railsTablePreferencesColumnKey
      const current = this.columnByKey(key) || {}
      return this.withColumnWidthMetadata({
        ...current,
        key,
        visible: row.querySelector('[data-field="visible"]')?.checked ?? true,
        order: this.positiveIntegerValue(row.querySelector('[data-field="order"]')?.value) ?? this.positiveIntegerValue(current.order) ?? (index + 1) * 10,
        width: this.clampColumnWidth(key, row.querySelector('[data-field="width"]')?.value),
        truncate: this.positiveIntegerValue(row.querySelector('[data-field="truncate"]')?.value),
        pinned: current.pinned === true
      })
    })
    const settings = { ...editorSettings, columns, filters: editorSettings?.filters || {}, sorts: editorSettings?.sorts || [] }
    return this.defaultSettings ? this.mergeSettings(this.defaultSettings, settings) : settings
  }

  filterPanelId(columnKey) {
    if (!this.editorIdPrefixValue) return super.filterPanelId(columnKey)

    const normalizedColumnKey = this.filterPanelIdSegment(columnKey, "column")
    return `rails-table-preferences-filter-panel-${this.filterPanelIdNamespace}-${normalizedColumnKey}`
  }

  get filterPanelIdNamespace() {
    if (this.editorIdPrefixValue) return this.filterPanelIdSegment(this.editorIdPrefixValue, "table")
    return `${this.filterPanelIdSegment(this.tableKeyValue, "table")}-${this.filterPanelInstanceId}`
  }

  filterPlaceholderAttribute(value) {
    const text = String(value ?? "").trim()
    if (!text) return ""
    return ` placeholder="${this.escapeHtml(text)}"`
  }

  filterInputAffordanceAttributes(filter, placeholder) {
    const attributes = [this.filterPlaceholderAttribute(placeholder)]
    if (["number", "date"].includes(this.filterInputType(filter)) || DATE_TIME_FILTER_TYPES.has(String(filter.type))) {
      attributes.push(this.filterInputAttribute("min", filter.min))
      attributes.push(this.filterInputAttribute("max", filter.max))
      attributes.push(this.filterInputAttribute("step", filter.step))
    }
    return attributes.join("")
  }

  filterInputAttribute(name, value) {
    const text = String(value ?? "").trim()
    if (!text) return ""
    return ` ${name}="${this.escapeHtml(text)}"`
  }

  connect() {
    this.statusState = "idle"
    this.currentPreferenceAction = null
    this.currentPreferenceActionContext = null
    super.connect()
    this.installDirtyStateTracking()
    this.markEditorClean()
    this.syncResetButtonState()
  }

  buildDefaultSettings() {
    const settings = super.buildDefaultSettings()
    return { ...settings, columns: settings.columns.map((column) => this.withColumnWidthMetadata(column)) }
  }

  mergeSettings(defaultSettings, savedSettings) {
    const settings = super.mergeSettings(defaultSettings, savedSettings)
    return { ...settings, columns: settings.columns.map((column) => this.withColumnWidthMetadata(column)) }
  }

  syncEditorWidthInputs() {
    if (!this.hasEditorRowsTarget) return
    this.editorRows.forEach((row) => {
      const column = this.columnByKey(row.dataset.railsTablePreferencesColumnKey)
      const widthInput = row.querySelector('[data-field="width"]')
      const width = this.clampColumnWidth(column?.key, column?.width)
      if (widthInput && width) widthInput.value = String(width)
    })
  }

  autoFitWidthForColumn(key) {
    const cells = Array.from(this.cellsFor(key)).filter((cell) => !cell.hidden && cell.offsetParent !== null)
    if (cells.length === 0) return null
    const measured = Math.max(...cells.map((cell) => this.measureAutoFitCellWidth(cell))) + this.normalizedResizeAutoFitPadding
    return this.clampColumnWidth(key, Math.ceil(measured), {
      min: this.normalizedResizeAutoFitMinWidth,
      max: this.normalizedResizeAutoFitMaxWidth
    })
  }

  applyColumn(column) {
    if (!column) return
    super.applyColumn(this.columnWithClampedWidth(column))
  }

  syncPinnedColumnOffsets() {
    let left = 0
    this.orderedColumnsFromSettings.forEach((column) => {
      const cells = Array.from(this.cellsFor(column.key))
      if (column.pinned !== true || column.visible === false) {
        cells.forEach((cell) => cell.style.removeProperty("--rails-table-preferences-pinned-left"))
        return
      }
      cells.forEach((cell) => cell.style.setProperty("--rails-table-preferences-pinned-left", `${left}px`))
      const firstVisibleCell = cells.find((cell) => !cell.hidden)
      left += this.clampColumnWidth(column.key, column.width) || Math.round(firstVisibleCell?.getBoundingClientRect().width || 0)
    })
  }

  columnWithClampedWidth(column) {
    return { ...column, width: this.clampColumnWidth(column.key, column.width) }
  }

  withColumnWidthMetadata(column) {
    const definition = this.columnDefinitions.find((candidate) => candidate.key === column.key) || {}
    const minWidth = this.positiveIntegerValue(definition.min_width)
    const maxWidth = this.positiveIntegerValue(definition.max_width)
    const attributes = { ...column }

    if (minWidth) attributes.min_width = minWidth
    else delete attributes.min_width

    if (maxWidth) attributes.max_width = maxWidth
    else delete attributes.max_width

    return attributes
  }

  columnWidthBounds(key, fallbacks = {}) {
    const definition = this.columnDefinitions.find((column) => column.key === key) || {}
    return {
      min: this.positiveIntegerValue(definition.min_width) ?? this.positiveIntegerValue(fallbacks.min),
      max: this.positiveIntegerValue(definition.max_width) ?? this.positiveIntegerValue(fallbacks.max)
    }
  }

  get columnDefinitions() {
    return Array.isArray(this.columnsValue) ? this.columnsValue : []
  }

  clampColumnWidth(key, width, fallbacks = {}) {
    const value = this.positiveIntegerValue(width)
    if (value === null) return null

    const { min, max } = this.columnWidthBounds(key, fallbacks)
    if (min !== null && max !== null && min > max) return min

    let clamped = value
    if (min !== null) clamped = Math.max(min, clamped)
    if (max !== null) clamped = Math.min(max, clamped)
    return clamped
  }

  positiveIntegerValue(value) {
    const integer = this.integerValue(value)
    return integer !== null && integer > 0 ? integer : null
  }

  disconnect() {
    this.uninstallDirtyStateTracking()
    super.disconnect()
  }

  applyFromEditor(event) {
    const wasBusy = this.busy
    const result = super.applyFromEditor(event)
    this.updateDirtyStateFromEditor()
    if (!wasBusy) {
      this.clearSuccessfulStatus()
      this.syncResetButtonState()
      this.dispatchPreferenceEvent("applied", { action: "apply" })
    }
    return result
  }

  resetEditor(event) {
    const wasBusy = this.busy
    const result = super.resetEditor(event)
    if (!wasBusy) this.markEditorClean()
    if (!wasBusy) {
      this.clearEditorSearchQuery()
      this.setStatus(this.resetStatusLabelValue, "success")
      this.syncResetButtonState()
      this.dispatchPreferenceEvent("applied", { action: "reset" })
    } else {
      this.updateDirtyStateFromEditor()
    }
    return result
  }

  renderEditor() {
    super.renderEditor()
    this.ensureEditorSearchControl()
    this.syncEditorSearchResults()
    this.syncEditorMoveButtons()
    this.updateDirtyStateFromEditor()
    this.syncResetButtonState()
  }

  buildEditorRow(column) {
    const row = super.buildEditorRow(column)
    this.replaceEditorDragHandle(row)
    const syncEditorDraftState = () => {
      this.clearSuccessfulStatus()
      this.syncResetButtonState()
    }
    row.addEventListener("input", syncEditorDraftState)
    row.addEventListener("change", syncEditorDraftState)
    row.dataset.railsTablePreferencesEditorSearchText = this.editorSearchTextForColumn(column)
    row.insertBefore(this.buildEditorMoveControls(), row.querySelector(".rails-table-preferences-editor__visible"))
    return row
  }

  editorSearchTextForColumn(column) {
    return [
      column.label,
      column.key,
      ...this.editorSearchGroupTokens(column.group)
    ].filter(Boolean).map((token) => String(token).toLowerCase()).join(" ")
  }

  editorSearchGroupTokens(group) {
    if (!group) return []
    if (Array.isArray(group)) return group.flatMap((item) => this.editorSearchGroupTokens(item))
    if (typeof group === "object") return [group.key, group.label].filter(Boolean)
    return [group]
  }

  replaceEditorDragHandle(row) {
    const handle = row.querySelector(".rails-table-preferences-editor__drag-handle")
    if (!handle) return

    const visualHandle = document.createElement("span")
    visualHandle.className = handle.className
    visualHandle.dataset.railsTablePreferencesEditorDragHandle = "visual"
    visualHandle.draggable = false
    visualHandle.setAttribute("aria-hidden", "true")
    visualHandle.textContent = handle.textContent || "↕"
    handle.replaceWith(visualHandle)
  }

  showAllEditorColumns(event) {
    this.setEditorColumnVisibility(event, true)
  }

  hideAllEditorColumns(event) {
    this.setEditorColumnVisibility(event, false)
  }

  setEditorColumnVisibility(event, visible) {
    if (this.busy) return
    if (event) event.preventDefault()
    this.editorRows.forEach((row) => {
      const visibleInput = row.querySelector('[data-field="visible"]')
      if (visibleInput) visibleInput.checked = visible === true
    })
    this.updateDirtyStateFromEditor()
    this.setStatus(visible ? this.visibilityBulkShownStatusLabelValue : this.visibilityBulkHiddenStatusLabelValue, "success")
    this.syncResetButtonState()
  }

  buildEditorMoveControls() {
    const controls = document.createElement("div")
    controls.className = "rails-table-preferences-editor__row-actions"
    controls.setAttribute("aria-label", this.orderLabelValue)

    const upButton = this.buildEditorMoveButton("up", this.moveUpLabelValue, "↑")
    const downButton = this.buildEditorMoveButton("down", this.moveDownLabelValue, "↓")
    controls.append(upButton, downButton)
    return controls
  }

  buildEditorMoveButton(direction, label, text) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "rails-table-preferences-editor__move-button"
    button.dataset.railsTablePreferencesMoveDirection = direction
    button.setAttribute("aria-label", label)
    button.title = label
    button.textContent = text
    button.addEventListener("click", (event) => this.moveEditorRow(event, direction === "up" ? -1 : 1))
    return button
  }

  moveEditorRow(event, direction) {
    if (this.busy) return
    if (event) event.preventDefault()
    const row = event.currentTarget.closest("[data-rails-table-preferences-column-key]")
    if (!row) return

    const rows = this.editorRowsForMovement
    const index = rows.indexOf(row)
    const target = rows[index + direction]
    if (index < 0 || !target) return

    if (direction < 0) this.editorRowsTarget.insertBefore(row, target)
    else this.editorRowsTarget.insertBefore(row, target.nextSibling)

    this.refreshEditorOrderInputs()
    this.syncEditorMoveButtons()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  ensureEditorSearchControl() {
    if (!this.hasEditorRowsTarget || this.editorSearchControl) return

    const wrapper = document.createElement("div")
    wrapper.className = "rails-table-preferences-editor__tools"
    wrapper.dataset.railsTablePreferencesEditorSearch = "true"

    const label = document.createElement("label")
    label.className = "rails-table-preferences-editor__search"
    const labelText = document.createElement("span")
    labelText.textContent = this.editorSearchLabelValue
    const input = document.createElement("input")
    input.type = "search"
    input.placeholder = this.editorSearchPlaceholderValue
    input.setAttribute("aria-label", this.editorSearchLabelValue)
    input.dataset.railsTablePreferencesEditorSearchInput = "true"
    input.addEventListener("input", () => this.syncEditorSearchResults())
    label.append(labelText, input)

    const empty = document.createElement("p")
    empty.className = "rails-table-preferences-editor__search-empty"
    empty.dataset.railsTablePreferencesEditorSearchEmpty = "true"
    empty.setAttribute("role", "status")
    empty.setAttribute("aria-live", "polite")
    empty.setAttribute("aria-atomic", "true")
    empty.hidden = true
    empty.textContent = this.editorNoSearchResultsLabelValue

    wrapper.append(label, empty)
    this.editorRowsTarget.before(wrapper)
  }

  clearEditorSearchQuery() {
    const input = this.editorSearchInput
    if (input) input.value = ""
    this.syncEditorSearchResults()
  }

  syncEditorSearchResults() {
    if (!this.hasEditorRowsTarget) return
    const query = this.editorSearchInput?.value.trim().toLowerCase() || ""
    let visibleCount = 0

    this.editorRows.forEach((row) => {
      const searchableText = row.dataset.railsTablePreferencesEditorSearchText || row.textContent.toLowerCase()
      const hidden = Boolean(query) && !searchableText.includes(query)
      row.hidden = hidden
      if (!hidden) visibleCount += 1
    })

    if (this.editorSearchEmptyMessage) this.editorSearchEmptyMessage.hidden = !query || visibleCount > 0
    this.syncEditorMoveButtons()
    this.syncResetButtonState()
  }

  syncEditorMoveButtons() {
    const rows = this.editorRowsForMovement
    this.editorRows.forEach((row) => {
      const index = rows.indexOf(row)
      row.querySelectorAll("[data-rails-table-preferences-move-direction]").forEach((button) => {
        const direction = button.dataset.railsTablePreferencesMoveDirection
        button.disabled = this.busy || row.hidden || index < 0 || (direction === "up" ? index === 0 : index === rows.length - 1)
      })
    })
  }

  setEditorRowsBusyState(busy) {
    super.setEditorRowsBusyState(busy)
    this.syncEditorMoveButtons()
    this.syncResetButtonState()
  }

  get editorRowsForMovement() {
    const visibleRows = this.editorRows.filter((row) => !row.hidden)
    return visibleRows.length > 0 ? visibleRows : this.editorRows
  }

  get editorSearchControl() {
    return this.element.querySelector("[data-rails-table-preferences-editor-search]")
  }

  get editorSearchInput() {
    return this.editorSearchControl?.querySelector("[data-rails-table-preferences-editor-search-input]")
  }

  get editorSearchEmptyMessage() {
    return this.editorSearchControl?.querySelector("[data-rails-table-preferences-editor-search-empty]")
  }

  dragEditorRowOver(event) {
    super.dragEditorRowOver(event)
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  dropEditorRow(event) {
    super.dropEditorRow(event)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncEditorMoveButtons()
    this.syncResetButtonState()
  }

  dragEditorRowEnd(event) {
    super.dragEditorRowEnd(event)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncEditorMoveButtons()
    this.syncResetButtonState()
  }

  resizeColumn(event) {
    super.resizeColumn(event)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  autoFitColumnFromHandle(event) {
    const wasBusy = this.busy
    const result = super.autoFitColumnFromHandle(event)
    this.updateDirtyStateFromEditor()
    if (!wasBusy) this.setStatus(this.resizeAutoFitStatusLabelValue, "success")
    this.syncResetButtonState()
    return result
  }

  dragTableColumnOver(event) {
    super.dragTableColumnOver(event)
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  dropTableColumn(event) {
    super.dropTableColumn(event)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  endTableColumnDrag(event) {
    super.endTableColumnDrag(event)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncEditorMoveButtons()
    this.syncResetButtonState()
  }

  toggleSortFromHeader(event, cell, column) {
    super.toggleSortFromHeader(event, cell, column)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  applyFilterPanel(key, panel) {
    super.applyFilterPanel(key, panel)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  clearFilter(key) {
    super.clearFilter(key)
    this.updateDirtyStateFromEditor()
    this.clearSuccessfulStatus()
    this.syncResetButtonState()
  }

  applyPreferencePayload(payload) {
    super.applyPreferencePayload(payload)
    this.markEditorClean()
    this.syncResetButtonState()
  }

  refreshEditorOrderInputs() {
    super.refreshEditorOrderInputs()
    this.updateDirtyStateFromEditor()
    this.syncResetButtonState()
  }

  installDirtyStateTracking() {
    this.ensureDirtyStateElement()
    if (this.dirtyStateTrackingInstalled) return
    if (!this.hasEditorRowsTarget) return

    this.boundUpdateDirtyStateFromEditor = this.updateDirtyStateFromEditor.bind(this)
    this.editorRowsTarget.addEventListener("input", this.boundUpdateDirtyStateFromEditor)
    this.editorRowsTarget.addEventListener("change", this.boundUpdateDirtyStateFromEditor)
    this.dirtyStateTrackingInstalled = true
  }

  uninstallDirtyStateTracking() {
    if (!this.dirtyStateTrackingInstalled || !this.hasEditorRowsTarget || !this.boundUpdateDirtyStateFromEditor) return

    this.editorRowsTarget.removeEventListener("input", this.boundUpdateDirtyStateFromEditor)
    this.editorRowsTarget.removeEventListener("change", this.boundUpdateDirtyStateFromEditor)
    this.boundUpdateDirtyStateFromEditor = null
    this.dirtyStateTrackingInstalled = false
  }

  ensureDirtyStateElement() {
    if (this.hasDirtyStateTarget) return

    const element = document.createElement("p")
    element.className = "rails-table-preferences-editor__hint rails-table-preferences-editor__dirty-state"
    element.dataset.railsTablePreferencesTarget = "dirtyState"
    element.setAttribute("aria-live", "polite")
    element.setAttribute("aria-atomic", "true")
    element.hidden = true

    if (this.hasStatusTarget) {
      this.statusTarget.parentNode.insertBefore(element, this.statusTarget)
    } else {
      this.element.appendChild(element)
    }
  }

  markEditorClean() {
    this.savedSettingsSnapshot = this.normalizedSettingsSignature(this.settingsFromEditor())
    this.updateDirtyStateFromEditor()
  }

  updateDirtyStateFromEditor() {
    if (!this.hasDirtyStateTarget || !this.hasEditorRowsTarget) return
    if (!this.savedSettingsSnapshot) this.savedSettingsSnapshot = this.normalizedSettingsSignature(this.settingsFromEditor())

    const dirty = this.normalizedSettingsSignature(this.settingsFromEditor()) !== this.savedSettingsSnapshot
    this.dirtyStateTarget.hidden = !dirty
    this.dirtyStateTarget.textContent = dirty ? this.dirtyStateLabelValue : ""
  }

  normalizedSettingsSignature(settings) {
    return JSON.stringify(this.normalizeSettingsValue(settings))
  }

  normalizeSettingsValue(value) {
    if (Array.isArray(value)) return value.map((item) => this.normalizeSettingsValue(item))
    if (value && typeof value === "object") {
      return Object.keys(value).sort().reduce((normalized, key) => {
        normalized[key] = this.normalizeSettingsValue(value[key])
        return normalized
      }, {})
    }
    return value ?? null
  }

  setStatus(message, state = "idle") {
    const nextState = message ? state : "idle"
    this.statusState = nextState
    this.syncStatusStateHook(nextState)
    super.setStatus(message)
  }

  syncStatusStateHook(state = this.statusState || "idle") {
    const target = this.hasStatusTarget ? this.statusTarget : null
    if (!target || typeof target.setAttribute !== "function") return
    target.setAttribute("data-rails-table-preferences-status-state", state || "idle")
  }

  clearSuccessfulStatus() {
    if (this.statusState === "success") this.setStatus("")
  }

  syncResetButtonState() {
    const button = this.resetEditorButton
    if (!button) return
    button.disabled = this.busy || this.editorMatchesDefaultSettings()
  }

  editorMatchesDefaultSettings() {
    try {
      return this.normalizedSettingsFingerprint(this.settingsFromEditor()) === this.normalizedSettingsFingerprint(this.defaultSettings)
    } catch (_error) {
      return false
    }
  }

  normalizedSettingsFingerprint(settings = {}) {
    const columns = Array.isArray(settings.columns) ? settings.columns.map((column) => ({
      key: String(column.key || ""),
      visible: column.visible === false ? false : true,
      order: Number.isFinite(Number(column.order)) ? Number(column.order) : null,
      width: Number.isFinite(Number(column.width)) ? Number(column.width) : null,
      truncate: Number.isFinite(Number(column.truncate)) ? Number(column.truncate) : null,
      pinned: column.pinned === true
    })) : []

    return JSON.stringify({
      columns,
      filters: settings.filters || {},
      sorts: Array.isArray(settings.sorts) ? settings.sorts : []
    })
  }

  get resetEditorButton() {
    if (typeof this.element?.querySelector !== "function") return null
    return this.element.querySelector("[data-action~='rails-table-preferences#resetEditor']")
  }

  async withBusyStatus(callback, { busyLabel, successLabel, errorLabel = this.operationFailedStatusLabelValue } = {}) {
    if (this.busy) return null
    const generation = this.lifecycleGeneration
    this.partialSuccess = null
    this.setBusyState(true)
    if (busyLabel) this.setStatus(busyLabel, "busy")

    try {
      const result = await callback()
      if (!this.lifecycleActive(generation)) return null
      const partialSuccessMessage = this.partialSuccess?.generation === generation ? this.partialSuccess.message : null
      if (partialSuccessMessage) this.setStatus(partialSuccessMessage, "warning")
      else if (successLabel) this.setStatus(successLabel, "success")
      return result
    } catch (error) {
      if (this.lifecycleActive(generation)) this.handleOperationError(error, errorLabel)
      return null
    } finally {
      if (this.lifecycleActive(generation)) {
        this.setBusyState(false)
        this.syncResetButtonState()
      }
      if (this.partialSuccess?.generation === generation) this.partialSuccess = null
    }
  }

  async save(event) {
    if (this.busy) return null
    if (!this.currentPreferenceEditable) return this.createPresetFromEditor(event)

    const generation = this.lifecycleGeneration
    const result = await this.withPreferenceAction("save", () => super.save(event))
    if (!this.lifecycleActive(generation)) return null
    if (result !== null && ["success", "warning"].includes(this.statusState)) {
      this.markEditorClean()
      this.dispatchPreferenceEvent("saved", { action: "save" })
    } else {
      this.updateDirtyStateFromEditor()
    }
    this.syncResetButtonState()
    return result
  }

  async createPresetFromEditor(event) {
    if (this.busy) return null

    const generation = this.lifecycleGeneration
    const result = await this.withPreferenceAction("create", () => super.createPresetFromEditor(event))
    if (!this.lifecycleActive(generation)) return null
    if (result !== null && ["success", "warning"].includes(this.statusState)) {
      this.markEditorClean()
      this.dispatchPreferenceEvent("saved", { action: "create" })
    } else {
      this.updateDirtyStateFromEditor()
    }
    this.syncResetButtonState()
    return result
  }

  async selectPreset(event) {
    if (this.busy) return null

    const generation = this.lifecycleGeneration
    const result = await this.withPreferenceAction("load", () => super.selectPreset(event))
    if (!this.lifecycleActive(generation)) return null
    if (result !== null && ["success", "warning"].includes(this.statusState)) {
      this.clearEditorSearchQuery()
      this.markEditorClean()
      this.dispatchPreferenceEvent("loaded", { action: "load" })
    } else {
      this.updateDirtyStateFromEditor()
    }
    this.syncResetButtonState()
    return result
  }

  async deletePreset(event) {
    if (event) event.preventDefault()
    if (!this.currentPreferenceEditable) return undefined
    if (!this.confirmDeletePreset()) return undefined

    const actionGeneration = this.lifecycleGeneration
    const deletedName = this.currentPresetName
    const result = await this.withPreferenceAction("delete", async () => {
      return this.withBusyStatus(async () => {
        const generation = this.lifecycleGeneration
        const response = await fetch(this.preferenceUrl(deletedName), {
          method: "DELETE",
          headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken }
        })
        if (!response.ok && response.status !== 204) throw new Error(`Failed to delete table preference preset: ${response.status}`)
        if (!this.lifecycleActive(generation)) return
        this.nameValue = "default"
        this.urlValue = this.preferenceUrl("default")
        this.currentPreferenceEditable = true
        this.setPresetNameInput("default")
        this.setDefaultPresetInput(false)
        this.settingsValue = this.defaultSettings
        this.closeFilterPanel()
        this.renderEditor()
        this.clearEditorSearchQuery()
        this.apply()
        this.broadcastSettingsSync()
        this.syncPresetEditingState()
        this.markEditorClean()
        this.syncResetButtonState()
        await this.refreshPresetOptionsAfterMutation(generation)
      }, {
        busyLabel: this.deletingStatusLabelValue,
        successLabel: this.deletedStatusLabelValue,
        errorLabel: this.deletingFailedStatusLabelValue
      })
    })
    if (!this.lifecycleActive(actionGeneration)) return null
    if (result !== null && ["success", "warning"].includes(this.statusState)) this.dispatchPreferenceEvent("deleted", { action: "delete", name: deletedName })
    return result
  }

  async refreshPresetOptionsOnConnect() {
    return this.withPreferenceAction("load-presets", () => super.refreshPresetOptionsOnConnect())
  }

  handleOperationError(error, message = this.operationFailedStatusLabelValue) {
    super.handleOperationError(error, message)
    this.statusState = "error"
    this.syncStatusStateHook("error")
    this.dispatchPreferenceEvent("error", {
      action: this.currentPreferenceAction || "operation",
      message: message || this.operationFailedStatusLabelValue
    })
  }

  withPreferenceAction(action, callback) {
    const generation = this.lifecycleGeneration
    const context = {
      action,
      generation,
      previous: this.currentPreferenceActionContext,
      active: true
    }
    this.currentPreferenceActionContext = context
    this.currentPreferenceAction = action
    const restore = () => {
      context.active = false
      if (this.lifecycleGeneration !== generation || this.currentPreferenceActionContext !== context) return
      let previous = context.previous
      while (previous && !previous.active) previous = previous.previous
      this.currentPreferenceActionContext = previous || null
      this.currentPreferenceAction = previous?.action || null
    }

    try {
      const result = callback()
      if (result && typeof result.then === "function") return result.finally(restore)
      restore()
      return result
    } catch (error) {
      restore()
      throw error
    }
  }

  dispatchPreferenceEvent(name, detail = {}) {
    this.dispatch(name, { detail: this.preferenceEventDetail(detail) })
  }

  preferenceEventDetail(detail = {}) {
    return {
      tableKey: this.tableKeyValue,
      name: this.currentPresetName,
      settings: this.settingsSnapshot(this.settingsValue),
      ...detail
    }
  }

  settingsSnapshot(settings) {
    if (typeof structuredClone === "function") return structuredClone(settings)
    return JSON.parse(JSON.stringify(settings || {}))
  }

  installTableColumnDragHandles() {
    this.headerCells.forEach((cell) => {
      if (cell.dataset.railsTablePreferencesTableDragInstalled === "true") return
      if (!this.tableColumnDraggable(cell)) {
        cell.draggable = false
        cell.dataset.railsTablePreferencesTableDragDisabled = "true"
        return
      }

      cell.draggable = true
      cell.dataset.railsTablePreferencesTableDragInstalled = "true"
      cell.classList.add("rails-table-preferences-table-column-draggable")
      cell.addEventListener("dragstart", this.startTableColumnDrag.bind(this))
      cell.addEventListener("dragover", this.dragTableColumnOver.bind(this))
      cell.addEventListener("drop", this.dropTableColumn.bind(this))
      cell.addEventListener("dragend", this.endTableColumnDrag.bind(this))
    })
  }

  startTableColumnDrag(event) {
    if (!this.tableColumnDraggable(event.currentTarget)) {
      event.preventDefault()
      return
    }

    super.startTableColumnDrag(event)
  }

  tableColumnDraggable(cell) {
    const key = cell?.dataset?.railsTablePreferencesColumnKey
    return this.columnDefinitionByKey(key)?.draggable !== false
  }

  installSortControls() {
    this.headerCells.forEach((cell) => {
      if (cell.dataset.railsTablePreferencesSortInstalled === "true") return
      if (cell.hasAttribute("title") && cell.title.trim() !== "") {
        cell.dataset.railsTablePreferencesHostTitle = cell.title
      }
    })

    super.installSortControls()
  }

  syncSortStates() {
    super.syncSortStates()

    this.headerCells.forEach((cell) => {
      if (cell.dataset.railsTablePreferencesHostTitle !== undefined) {
        cell.title = cell.dataset.railsTablePreferencesHostTitle
      }
    })
  }

  installResizeHandles() {
    super.installResizeHandles()
    this.element.querySelectorAll("[data-rails-table-preferences-resize-handle]").forEach((handle) => {
      if (handle.dataset.railsTablePreferencesKeyboardAutoFitInstalled === "true") return
      handle.dataset.railsTablePreferencesKeyboardAutoFitInstalled = "true"
      handle.addEventListener("keydown", this.autoFitColumnFromResizeHandleKeyboard.bind(this))
    })
  }

  autoFitColumnFromResizeHandleKeyboard(event) {
    if (!this.isResizeHandleAutoFitKey(event)) return
    event.preventDefault()
    this.autoFitColumnFromHandle(event)
  }

  isResizeHandleAutoFitKey(event) {
    return event.key === "Enter" || event.key === " " || event.key === "Spacebar"
  }

  showAllColumns(event) {
    if (this.busy) return
    if (event) event.preventDefault()

    this.settingsValue = {
      ...this.settingsValue,
      columns: this.columnsFromSettings.map((column) => ({ ...column, visible: true })),
      filters: this.settingsValue?.filters || {},
      sorts: this.settingsValue?.sorts || []
    }
    this.closeFilterPanel()
    this.renderEditor()
    this.apply()
    this.broadcastSettingsSync()
    this.markEditorClean()
    this.syncResetButtonState()
  }

  clearFiltersAndSorts(event) {
    if (this.busy) return
    if (event) event.preventDefault()
    this.settingsValue = { ...this.settingsValue, filters: {}, sorts: [] }
    this.closeFilterPanel()
    this.apply()
    this.broadcastSettingsSync()
    this.updateDirtyStateFromEditor()
    this.syncResetButtonState()
    this.dispatchPreferenceEvent("applied", { action: "clear-filters-and-sorts" })
  }

  openFilterPanel(headerCell, column, button = headerCell.querySelector("[data-rails-table-preferences-filter-button]")) {
    super.openFilterPanel(headerCell, column, button)
    if (!this.filterPanel) return

    this.filterPanel.setAttribute("role", "group")
    this.filterPanel.setAttribute("aria-labelledby", this.filterPanelTitleId(column.key))
    this.installSelectFilterOptionSearch(this.filterPanel)
  }

  filterPanelHtml(column) {
    return super.filterPanelHtml(column).replace(
      'class="rails-table-preferences-filter-panel__title"',
      `id="${this.filterPanelTitleId(column.key)}" class="rails-table-preferences-filter-panel__title"`
    )
  }

  filterPanelTitleId(key) {
    return `${this.filterPanelId(key)}-title`
  }

  positionFilterPanel(panel, headerCell) {
    const rect = headerCell.getBoundingClientRect()
    const viewportMargin = 8
    const panelWidth = panel.offsetWidth || panel.getBoundingClientRect().width || 0
    const minLeft = window.scrollX + viewportMargin
    const maxLeft = window.scrollX + window.innerWidth - panelWidth - viewportMargin
    const desiredLeft = window.scrollX + rect.left
    const left = panelWidth > 0 ? Math.max(minLeft, Math.min(desiredLeft, maxLeft)) : desiredLeft

    panel.style.position = "absolute"
    panel.style.top = `${window.scrollY + rect.bottom + 4}px`
    panel.style.left = `${left}px`
    panel.style.maxWidth = `calc(100vw - ${viewportMargin * 2}px)`
    panel.style.zIndex = "1000"
  }

  renderFilterPanelValueFields(panel, column) {
    super.renderFilterPanelValueFields(panel, column)
    this.installSelectFilterOptionSearch(panel)
  }

  filterValueHtml(filter, condition, selectedOperator) {
    if (filter.type === "select" && Array.isArray(filter.options) && !["blank", "present", "true", "false"].includes(selectedOperator)) {
      const values = new Set(Array(condition.values || condition.value || []).map(String))
      const optionsHtml = filter.options.map((option) => {
        const value = this.selectFilterOptionValue(option)
        const label = this.selectFilterOptionLabel(option, value)
        return `<option value="${this.escapeHtml(value)}" ${values.has(String(value)) ? "selected" : ""}>${this.escapeHtml(label)}</option>`
      }).join("")
      return `<label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterValueLabelValue)}${this.selectFilterOptionSearchHtml(filter.options)}<select data-field="values" multiple>${optionsHtml}</select></label>`
    }

    const inputType = this.filterInputType(filter)
    if (["text", "number", "date", "datetime-local", "time"].includes(inputType)) {
      if (["blank", "present", "true", "false"].includes(selectedOperator)) return ""
      if (selectedOperator === "between") {
        const fromAttributes = this.filterInputAffordanceAttributes(filter, filter.from_placeholder)
        const toAttributes = this.filterInputAffordanceAttributes(filter, filter.to_placeholder)
        return `
          <label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterFromLabelValue)}<input type="${inputType}" data-field="from" value="${this.escapeHtml(condition.from ?? "")}"${fromAttributes}></label>
          <label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterToLabelValue)}<input type="${inputType}" data-field="to" value="${this.escapeHtml(condition.to ?? "")}"${toAttributes}></label>
        `
      }

      const attributes = this.filterInputAffordanceAttributes(filter, filter.placeholder)
      return `<label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterValueLabelValue)}<input type="${inputType}" data-field="value" value="${this.escapeHtml(condition.value ?? "")}"${attributes}></label>`
    }

    return super.filterValueHtml(filter, condition, selectedOperator)
  }

  selectFilterOptionSearchHtml(options) {
    if (!Array.isArray(options) || options.length === 0 || options.length < this.selectFilterOptionSearchThreshold) return ""

    const searchLabel = this.selectFilterOptionSearchLabelValue || "候補を絞り込み"
    const searchPlaceholder = this.selectFilterOptionSearchPlaceholderValue || "候補を絞り込み"
    const label = `${this.filterValueLabelValue}: ${searchLabel}`
    const emptyLabel = "一致する候補はありません。選択済みの候補は表示したままです。"
    return `<input type="search" class="rails-table-preferences-filter-panel__option-search" data-field="option-search" aria-label="${this.escapeHtml(label)}" placeholder="${this.escapeHtml(searchPlaceholder)}"><p class="rails-table-preferences-filter-panel__option-search-empty" data-rails-table-preferences-option-search-empty role="status" aria-live="polite" aria-atomic="true" hidden>${this.escapeHtml(emptyLabel)}</p>`
  }

  installSelectFilterOptionSearch(panel) {
    const input = panel?.querySelector("[data-field='option-search']")
    const select = panel?.querySelector("[data-field='values']")
    const emptyMessage = panel?.querySelector("[data-rails-table-preferences-option-search-empty]")
    if (!input || !select || input.dataset.railsTablePreferencesOptionSearchInstalled === "true") return

    input.dataset.railsTablePreferencesOptionSearchInstalled = "true"
    input.addEventListener("input", () => this.filterSelectOptionsBySearch(input, select, emptyMessage))
    select.addEventListener("change", () => this.filterSelectOptionsBySearch(input, select, emptyMessage))
    this.filterSelectOptionsBySearch(input, select, emptyMessage)
  }

  filterSelectOptionsBySearch(input, select, emptyMessage = null) {
    const query = String(input?.value || "").trim().toLocaleLowerCase()
    let matchingOptions = 0

    Array.from(select?.options || []).forEach((option) => {
      const searchableText = `${option.textContent || ""} ${option.value || ""}`.toLocaleLowerCase()
      const matchesQuery = searchableText.includes(query)
      if (matchesQuery) matchingOptions += 1
      option.hidden = Boolean(query) && !option.selected && !matchesQuery
    })

    if (emptyMessage) emptyMessage.hidden = !query || matchingOptions > 0
  }

  selectFilterOptionValue(option) {
    if (option && typeof option === "object" && !Array.isArray(option)) {
      return String(option.value ?? option.label ?? "")
    }

    return String(option ?? "")
  }

  selectFilterOptionLabel(option, fallbackValue = this.selectFilterOptionValue(option)) {
    if (option && typeof option === "object" && !Array.isArray(option)) {
      return String(option.label ?? option.value ?? fallbackValue)
    }

    return String(option ?? "")
  }

  get selectFilterOptionSearchThreshold() {
    const rawValue = this.element?.dataset?.railsTablePreferencesSelectFilterOptionSearchThresholdValue
    if (rawValue !== undefined && String(rawValue).trim() === "") return 8

    const threshold = Number(this.selectFilterOptionSearchThresholdValue)
    if (!Number.isFinite(threshold)) return 8
    return Math.floor(threshold)
  }

  filterOperatorsFor(filter) {
    if (Array.isArray(filter.operators) && filter.operators.length > 0) return filter.operators.map(String)
    if (DATE_TIME_FILTER_TYPES.has(String(filter.type))) return ["equals", "gteq", "lteq", "between", "blank", "present"]
    return super.filterOperatorsFor(filter)
  }

  filterInputType(filter) {
    const type = String(filter.type)
    if (type === "datetime" || type === "datetime-local") return "datetime-local"
    if (type === "time") return "time"
    return super.filterInputType(filter)
  }

  filterOperatorText(operator) {
    const key = String(operator)
    const override = this.filterOperatorLabelsValue?.[key]
    if (override !== undefined && override !== null && String(override).trim() !== "") return String(override)
    return super.filterOperatorText(key)
  }
}
