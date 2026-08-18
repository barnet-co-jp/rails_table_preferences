import RailsTablePreferencesController from "./controller.js"

const settingsSyncEventName = "rails-table-preferences:settings-sync"
const columnLayoutSyncMode = "column-layout"

export default class RailsTablePreferencesPresetSelectRecoveryController extends RailsTablePreferencesController {
  static values = {
    ...(RailsTablePreferencesController.values || {}),
    presetSearchClearLabel: { type: String, default: "検索をクリア" },
    editorSearchResultCountLabel: { type: String, default: "表示中の列: {visible} / {total}" }
  }

  filterButtonLabel(column, condition = {}) {
    const columnLabel = column?.label || column?.key || this.filterLabelValue
    const baseLabel = `${this.filterLabelValue}: ${columnLabel}`
    const summary = this.filterConditionSummaryForColumn(column, condition)
    return summary ? `${baseLabel} (${summary})` : baseLabel
  }

  filterConditionSummaryForColumn(column, condition = {}) {
    const filter = column?.filter || {}
    if (String(filter.type) !== "select" || !Array.isArray(filter.options)) {
      return super.filterConditionSummary(condition)
    }

    const operator = String(condition?.operator || "").trim()
    if (!operator) return ""
    const operatorText = this.filterOperatorText(operator)
    if (["blank", "present", "true", "false"].includes(operator)) return operatorText

    const values = this.selectFilterSummaryValues(condition)
    if (values.length === 0) return operatorText

    const labels = values
      .map((value) => this.selectFilterOptionSummaryLabel(filter, value))
      .map((value) => this.filterSummaryText(value))
      .filter(Boolean)

    return labels.length > 0 ? `${operatorText}: ${this.filterSummaryValues(labels)}` : operatorText
  }

  selectFilterSummaryValues(condition = {}) {
    if (Array.isArray(condition.values)) return condition.values
    if (condition.value !== undefined && condition.value !== null && String(condition.value) !== "") return [condition.value]
    return []
  }

  selectFilterOptionSummaryLabel(filter, value) {
    const rawValue = String(value ?? "")
    const option = (filter.options || []).find((candidate) => this.selectFilterOptionValue(candidate) === rawValue)
    if (!option) return rawValue
    return this.selectFilterOptionLabel(option, rawValue)
  }

  positionFilterPanel(panel, headerCell) {
    super.positionFilterPanel(panel, headerCell)

    const rect = headerCell.getBoundingClientRect()
    const viewportMargin = 8
    const panelTop = window.scrollY + rect.bottom + 4
    const viewportBottom = window.scrollY + window.innerHeight - viewportMargin
    const availableHeight = Math.max(viewportMargin, viewportBottom - panelTop)

    panel.style.maxHeight = `${availableHeight}px`
    panel.style.overflowY = "auto"
  }

  ensurePresetSearchControl() {
    super.ensurePresetSearchControl()
    if (!this.presetSearchControl || this.presetSearchClearButton) return

    const button = document.createElement("button")
    button.type = "button"
    button.className = "rails-table-preferences-editor__search-clear"
    button.dataset.railsTablePreferencesPresetSearchClear = "true"
    button.textContent = this.presetSearchClearLabelValue || "検索をクリア"
    button.setAttribute("aria-label", this.presetSearchClearLabelValue || "検索をクリア")
    button.hidden = true
    button.addEventListener("click", (event) => this.clearPresetSearchQuery(event))

    const emptyMessage = this.presetSearchEmptyMessage
    if (emptyMessage?.parentNode) emptyMessage.parentNode.insertBefore(button, emptyMessage)
    else this.presetSearchControl.appendChild(button)
  }

  syncPresetSearchState({ query, visibleCount, enabled }) {
    super.syncPresetSearchState({ query, visibleCount, enabled })

    const hasQuery = enabled && Boolean(query)
    if (this.presetSearchClearButton) {
      this.presetSearchClearButton.hidden = !hasQuery
      this.presetSearchClearButton.disabled = this.busy || !hasQuery
    }
  }

  clearPresetSearchQuery(event) {
    if (event) event.preventDefault()
    if (this.busy) return

    const input = this.presetSearchInput
    if (!input) return

    input.value = ""
    this.renderPresetOptions()
    if (typeof input.focus === "function") input.focus()
  }

  get presetSearchClearButton() {
    return this.presetSearchControl?.querySelector("[data-rails-table-preferences-preset-search-clear]")
  }

  ensureEditorSearchControl() {
    super.ensureEditorSearchControl()
    if (!this.editorSearchControl || this.editorSearchCountMessage) return

    const count = document.createElement("p")
    count.className = "rails-table-preferences-editor__search-empty rails-table-preferences-editor__search-count"
    count.dataset.railsTablePreferencesEditorSearchCount = "true"
    count.setAttribute("aria-live", "polite")
    count.setAttribute("aria-atomic", "true")
    count.hidden = true

    const emptyMessage = this.editorSearchEmptyMessage
    if (emptyMessage?.parentNode) emptyMessage.parentNode.insertBefore(count, emptyMessage)
    else this.editorSearchControl.appendChild(count)
  }

  syncEditorSearchResults() {
    super.syncEditorSearchResults()
    if (!this.hasEditorRowsTarget) return

    const query = this.editorSearchInput?.value.trim().toLowerCase() || ""
    const visibleCount = this.editorRows.filter((row) => !row.hidden).length
    this.syncEditorSearchCount({ query, visibleCount, totalCount: this.editorRows.length })
  }

  syncEditorSearchCount({ query, visibleCount, totalCount }) {
    const count = this.editorSearchCountMessage
    if (!count) return

    const showCount = Boolean(query) && visibleCount > 0
    count.hidden = !showCount
    count.textContent = showCount ? this.editorSearchResultCountText(visibleCount, totalCount) : ""
  }

  editorSearchResultCountText(visibleCount, totalCount) {
    const template = this.editorSearchResultCountLabelValue || "表示中の列: {visible} / {total}"
    return template
      .replace("{visible}", String(visibleCount))
      .replace("{total}", String(totalCount))
  }

  get editorSearchCountMessage() {
    return this.editorSearchControl?.querySelector("[data-rails-table-preferences-editor-search-count]")
  }

  async selectPreset(event) {
    if (this.busy) return null

    const appliedPresetName = this.nameValue || this.currentPresetName
    const result = await super.selectPreset(event)

    if (this.statusState !== "success") this.restorePresetSelectToAppliedPreset(appliedPresetName)
    return result
  }

  restorePresetSelectToAppliedPreset(name) {
    if (!this.hasPresetSelectTarget) return

    this.presetSelectTarget.value = name || "default"
    this.syncDeletePresetButtonContext()
  }

  receiveSettingsSync(event) {
    const detail = event.detail || {}
    if (detail.syncMode !== columnLayoutSyncMode) return super.receiveSettingsSync(event)
    if (!this.connected || event.target === this.element) return
    if (String(detail.tableKey) !== String(this.tableKeyValue)) return
    if (!detail.settings || typeof detail.settings !== "object" || Array.isArray(detail.settings)) return

    this.settingsValue = this.mergeColumnLayoutSettings(this.settingsValue || {}, detail.settings)
    if (this.hasEditorRowsTarget) this.refreshEditorFromSettings()
    if (this.tableElement) this.apply()
  }

  mergeColumnLayoutSettings(currentSettings, sourceSettings) {
    const sourceColumns = new Map(Array(sourceSettings?.columns || []).map((column) => [column.key, column]))
    const columns = Array(currentSettings?.columns || []).map((column) => {
      const source = sourceColumns.get(column.key)
      if (!source) return column

      return this.withColumnWidthMetadata({
        ...column,
        order: source.order ?? column.order,
        width: source.width ?? column.width
      })
    }).sort((left, right) => this.orderValue(left) - this.orderValue(right))

    return { ...currentSettings, columns }
  }

  broadcastColumnLayoutSync() {
    if (typeof CustomEvent === "undefined" || !this.element?.dispatchEvent) return

    this.element.dispatchEvent(new CustomEvent(settingsSyncEventName, {
      bubbles: true,
      detail: {
        tableKey: this.tableKeyValue,
        name: this.currentPresetName,
        settings: this.settingsSyncSnapshot(this.settingsValue || {}),
        syncMode: columnLayoutSyncMode
      }
    }))
  }

  stopColumnResize() {
    const hadActiveResize = Boolean(this.resizingColumn)
    const result = super.stopColumnResize()
    if (hadActiveResize) this.broadcastColumnLayoutSync()
    return result
  }

  autoFitColumnFromHandle(event) {
    const previous = this.stateChangeFingerprint()
    const result = super.autoFitColumnFromHandle(event)
    if (previous !== this.stateChangeFingerprint()) this.broadcastColumnLayoutSync()
    return result
  }

  endTableColumnDrag(event) {
    const hadActiveDrag = Boolean(this.draggedTableColumnKey)
    const result = super.endTableColumnDrag(event)
    if (hadActiveDrag) this.broadcastColumnLayoutSync()
    return result
  }

  toggleSortFromHeader(event, cell, column) {
    const previous = this.stateChangeFingerprint()
    const result = super.toggleSortFromHeader(event, cell, column)
    this.dispatchStateChangedIfNeeded(previous, "sort-change")
    return result
  }

  applyFilterPanel(key, panel) {
    const previous = this.stateChangeFingerprint()
    const result = super.applyFilterPanel(key, panel)
    this.dispatchStateChangedIfNeeded(previous, "filter-change")
    return result
  }

  clearFilter(key) {
    const previous = this.stateChangeFingerprint()
    const result = super.clearFilter(key)
    this.dispatchStateChangedIfNeeded(previous, "filter-clear")
    return result
  }

  dispatchStateChangedIfNeeded(previousFingerprint, action) {
    if (previousFingerprint === this.stateChangeFingerprint()) return
    this.dispatchPreferenceEvent("state-changed", { action })
  }

  stateChangeFingerprint() {
    return this.normalizedSettingsSignature(this.settingsValue || {})
  }
}
