import { Controller } from "@hotwired/stimulus"

let filterPanelInstanceSequence = 0
const settingsSyncEventName = "rails-table-preferences:settings-sync"

// Applies and edits saved table display preferences for a server-rendered table.
export default class extends Controller {
  static targets = ["editorRows", "presetName", "presetSelect", "defaultPreset", "status", "readOnlyHint"]

  static values = {
    tableKey: String,
    name: { type: String, default: "default" },
    url: String,
    collectionUrl: String,
    settings: Object,
    columns: Array,
    resizeHandleWidth: { type: Number, default: 10 },
    resizeAutoFitPadding: { type: Number, default: 24 },
    resizeAutoFitMinWidth: { type: Number, default: 40 },
    resizeAutoFitMaxWidth: { type: Number, default: 640 },
    reorderSensitivity: { type: Number, default: 1.2 },
    orderLabel: { type: String, default: "表示順" },
    widthLabel: { type: String, default: "列幅" },
    truncateLabel: { type: String, default: "省略文字数" },
    dragLabel: { type: String, default: "ドラッグして並び替え" },
    resizeLabel: { type: String, default: "列幅を変更" },
    filterLabel: { type: String, default: "絞り込み" },
    filterApplyLabel: { type: String, default: "適用" },
    filterClearLabel: { type: String, default: "クリア" },
    filterOperatorLabel: { type: String, default: "条件" },
    filterValueLabel: { type: String, default: "値" },
    filterFromLabel: { type: String, default: "開始" },
    filterToLabel: { type: String, default: "終了" },
    sortAscLabel: { type: String, default: "昇順" },
    sortDescLabel: { type: String, default: "降順" },
    sortClearLabel: { type: String, default: "並び替え解除" },
    sortPriorityLabel: { type: String, default: "並び替え優先順位" },
    deleteConfirmLabel: { type: String, default: "この保存済み設定を削除します。よろしいですか？" },
    readOnlyPresetHintLabel: { type: String, default: "この設定は直接上書きできません。保存すると個人用の新しい設定として保存されます。" },
    scopeOwnerLabel: { type: String, default: "個人" },
    scopeSharedLabel: { type: String, default: "共有" },
    scopeRoleLabel: { type: String, default: "ロール" },
    scopeOrganizationLabel: { type: String, default: "組織" },
    loadingStatusLabel: { type: String, default: "設定を読み込み中です..." },
    loadedStatusLabel: { type: String, default: "設定を読み込みました。" },
    loadingFailedStatusLabel: { type: String, default: "設定の読み込みを完了できませんでした。" },
    savingStatusLabel: { type: String, default: "設定を保存中です..." },
    savedStatusLabel: { type: String, default: "設定を保存しました。" },
    savingFailedStatusLabel: { type: String, default: "設定の保存を完了できませんでした。" },
    savingAsNewStatusLabel: { type: String, default: "新しい設定を保存中です..." },
    savedAsNewStatusLabel: { type: String, default: "新しい設定を保存しました。" },
    savingAsNewFailedStatusLabel: { type: String, default: "新しい設定の保存を完了できませんでした。" },
    deletingStatusLabel: { type: String, default: "設定を削除中です..." },
    deletedStatusLabel: { type: String, default: "設定を削除しました。" },
    deletingFailedStatusLabel: { type: String, default: "設定の削除を完了できませんでした。" },
    resetStatusLabel: { type: String, default: "テーブル初期設定に戻しました。" },
    presetListRefreshFailedStatusLabel: { type: String, default: "設定は反映されましたが、一覧を更新できませんでした。画面を再読み込みしてください。" },
    operationFailedStatusLabel: { type: String, default: "設定の操作を完了できませんでした。" }
  }

  connect() {
    this.lifecycleGeneration = (this.lifecycleGeneration || 0) + 1
    this.connected = true
    this.installSettingsSyncListener()
    this.filterPanelInstanceId ||= ++filterPanelInstanceSequence
    this.busy = false
    this.draggedEditorRow = null
    this.draggedTableColumnKey = null
    this.resizingColumn = null
    this.filterPanel = null
    this.filterPanelButton = null
    this.filterPanelHeaderCell = null
    this.presets = []
    this.currentPreferenceEditable = true
    this.defaultSettings = this.buildDefaultSettings()
    this.settingsValue = this.mergeSettings(this.defaultSettings, this.settingsValue || {})
    this.renderEditor()
    this.apply()
    this.installResizeHandles()
    this.installTableColumnDragHandles()
    this.installFilterControls()
    this.installSortControls()
    this.setStatus("")
    this.refreshPresetOptionsOnConnect()
  }

  disconnect() {
    this.connected = false
    this.lifecycleGeneration = (this.lifecycleGeneration || 0) + 1
    this.uninstallSettingsSyncListener()
    this.uninstallDocumentResizeListeners()
    this.closeFilterPanel()
  }

  installSettingsSyncListener() {
    if (typeof document === "undefined") return
    this.settingsSyncListener ||= this.receiveSettingsSync.bind(this)
    document.addEventListener(settingsSyncEventName, this.settingsSyncListener)
  }

  uninstallSettingsSyncListener() {
    if (typeof document === "undefined" || !this.settingsSyncListener) return
    document.removeEventListener(settingsSyncEventName, this.settingsSyncListener)
  }

  broadcastSettingsSync() {
    if (typeof CustomEvent === "undefined" || !this.element?.dispatchEvent) return

    this.element.dispatchEvent(new CustomEvent(settingsSyncEventName, {
      bubbles: true,
      detail: {
        tableKey: this.tableKeyValue,
        name: this.currentPresetName,
        settings: this.settingsSyncSnapshot(this.settingsValue)
      }
    }))
  }

  receiveSettingsSync(event) {
    if (!this.connected || event.target === this.element || !this.tableElement) return

    const detail = event.detail || {}
    if (String(detail.tableKey) !== String(this.tableKeyValue)) return
    if (!detail.settings || typeof detail.settings !== "object" || Array.isArray(detail.settings)) return

    this.nameValue = detail.name || "default"
    this.urlValue = this.preferenceUrl(this.nameValue)
    this.settingsValue = this.mergeSettings(this.defaultSettings, detail.settings)
    this.apply()
  }

  settingsSyncSnapshot(settings) {
    if (typeof structuredClone === "function") return structuredClone(settings || {})
    return JSON.parse(JSON.stringify(settings || {}))
  }

  apply() {
    this.applyColumnOrder()
    this.columnsFromSettings.forEach((column) => this.applyColumn(column))
    this.syncPinnedColumnOffsets()
    this.syncEditorWidthInputs()
    this.syncFilterButtonStates()
    this.syncSortStates()
  }

  applyFromEditor(event) {
    if (this.busy) return
    if (event) event.preventDefault()
    this.settingsValue = this.settingsFromEditor()
    this.apply()
    this.broadcastSettingsSync()
  }

  async saveFromEditor(event) {
    if (event) event.preventDefault()
    this.settingsValue = this.settingsFromEditor()
    if (!this.currentPreferenceEditable) return this.createPresetFromEditor()
    await this.save()
  }

  async createPresetFromEditor(event) {
    if (event) event.preventDefault()
    this.settingsValue = this.settingsFromEditor()

    return this.withBusyStatus(async () => {
      const generation = this.lifecycleGeneration
      const response = await fetch(this.collectionUrlValue, {
        method: "POST",
        headers: this.jsonHeaders,
        body: JSON.stringify({ name: this.currentPresetName, settings: this.settingsValue, default: this.defaultPresetChecked })
      })
      if (!response.ok) throw new Error(`Failed to create table preference preset: ${response.status}`)
      const payload = await response.json()
      if (!this.lifecycleActive(generation)) return
      this.applyPreferencePayload(payload)
      await this.refreshPresetOptionsAfterMutation(generation)
    }, {
      busyLabel: this.savingAsNewStatusLabelValue,
      successLabel: this.savedAsNewStatusLabelValue,
      errorLabel: this.savingAsNewFailedStatusLabelValue
    })
  }

  async deletePreset(event) {
    if (event) event.preventDefault()
    if (!this.currentPreferenceEditable) return
    if (!this.confirmDeletePreset()) return

    return this.withBusyStatus(async () => {
      const generation = this.lifecycleGeneration
      const response = await fetch(this.preferenceUrl(this.currentPresetName), {
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
      this.apply()
      this.broadcastSettingsSync()
      this.syncPresetEditingState()
      await this.refreshPresetOptionsAfterMutation(generation)
    }, {
      busyLabel: this.deletingStatusLabelValue,
      successLabel: this.deletedStatusLabelValue,
      errorLabel: this.deletingFailedStatusLabelValue
    })
  }

  async save(event) {
    if (event) event.preventDefault()
    if (!this.currentPreferenceEditable) return this.createPresetFromEditor()

    return this.withBusyStatus(async () => {
      const generation = this.lifecycleGeneration
      const response = await fetch(this.preferenceUrl(this.currentPresetName), {
        method: "PATCH",
        headers: this.jsonHeaders,
        body: JSON.stringify({ settings: this.settingsValue, default: this.defaultPresetChecked })
      })
      if (!response.ok) throw new Error(`Failed to save table preferences: ${response.status}`)
      const payload = await response.json()
      if (!this.lifecycleActive(generation)) return
      this.applyPreferencePayload(payload)
      await this.refreshPresetOptionsAfterMutation(generation)
    }, {
      busyLabel: this.savingStatusLabelValue,
      successLabel: this.savedStatusLabelValue,
      errorLabel: this.savingFailedStatusLabelValue
    })
  }

  resetEditor(event) {
    if (this.busy) return
    if (event) event.preventDefault()
    this.settingsValue = this.defaultSettings
    this.closeFilterPanel()
    this.renderEditor()
    this.apply()
    this.broadcastSettingsSync()
    this.setStatus(this.resetStatusLabelValue)
  }

  async loadPresets() {
    const response = await fetch(this.collectionUrlValue, { headers: { "Accept": "application/json" } })
    if (!response.ok) throw new Error(`Failed to load table preference presets: ${response.status}`)
    return response.json()
  }

  async refreshPresetOptions() {
    if (!this.hasPresetSelectTarget) return
    const generation = this.lifecycleGeneration
    const payload = await this.loadPresets()
    if (!this.lifecycleActive(generation)) return
    this.presets = payload.preferences || []
    this.renderPresetOptions()
  }

  async refreshPresetOptionsAfterMutation(generation = this.lifecycleGeneration) {
    try {
      await this.refreshPresetOptions()
      return true
    } catch (error) {
      console.error(error)
      if (this.lifecycleActive(generation)) {
        this.partialSuccess = { generation, message: this.presetListRefreshFailedStatusLabelValue }
      }
      return false
    }
  }

  lifecycleActive(generation) {
    return this.connected !== false && generation === this.lifecycleGeneration
  }

  async refreshPresetOptionsOnConnect() {
    return this.withBusyStatus(async () => {
      await this.refreshPresetOptions()
    }, {
      busyLabel: this.loadingStatusLabelValue,
      successLabel: this.loadedStatusLabelValue,
      errorLabel: this.loadingFailedStatusLabelValue
    })
  }

  renderPresetOptions() {
    if (!this.hasPresetSelectTarget) return
    this.presetSelectTarget.innerHTML = ""
    const presets = this.presets.length ? this.presets : [{ name: this.currentPresetName, default: false, editable: true }]
    const groups = this.groupPresetsForSelect(presets)
    if (groups.length <= 1) {
      presets.forEach((preset) => this.presetSelectTarget.appendChild(this.buildPresetOption(preset)))
    } else {
      groups.forEach((group) => {
        const optgroup = document.createElement("optgroup")
        optgroup.label = group.label
        group.presets.forEach((preset) => optgroup.appendChild(this.buildPresetOption(preset)))
        this.presetSelectTarget.appendChild(optgroup)
      })
    }
    this.presetSelectTarget.value = this.currentPresetName
    this.syncDeletePresetButtonContext()
  }

  groupPresetsForSelect(presets) {
    const scopeOrder = new Map([["owner", 0], ["role", 1], ["organization", 2], ["shared", 3]])
    const groups = new Map()
    presets.forEach((preset, index) => {
      const scopeType = preset.scope_type || "owner"
      const groupKey = scopeOrder.has(scopeType) ? scopeType : `unknown:${scopeType}`
      if (!groups.has(groupKey)) {
        groups.set(groupKey, {
          key: groupKey,
          scopeType,
          order: scopeOrder.has(scopeType) ? scopeOrder.get(scopeType) : 100 + index,
          label: this.scopeGroupLabel(scopeType),
          presets: []
        })
      }
      groups.get(groupKey).presets.push(preset)
    })
    return Array.from(groups.values()).sort((left, right) => left.order - right.order)
  }

  scopeGroupLabel(scopeType) {
    return this.scopeFallbackLabel(scopeType || "owner")
  }

  buildPresetOption(preset) {
    const option = document.createElement("option")
    const name = preset.name || "default"
    const scopeType = preset.scope_type || "owner"
    const scopeLabel = preset.scope_label || this.scopeFallbackLabel(scopeType)
    const defaultMark = preset.default === true ? " *" : ""
    const scopeMark = scopeType !== "owner" && scopeLabel ? ` [${scopeLabel}]` : ""
    option.value = name
    option.textContent = `${name}${scopeMark}${defaultMark}`
    option.dataset.default = preset.default === true ? "true" : "false"
    option.dataset.editable = preset.editable === false ? "false" : "true"
    option.dataset.scopeType = scopeType
    option.dataset.scopeKey = preset.scope_key || ""
    return option
  }

  scopeFallbackLabel(scopeType) {
    switch (scopeType) {
      case "shared": return this.scopeSharedLabelValue
      case "role": return this.scopeRoleLabelValue
      case "organization": return this.scopeOrganizationLabelValue
      case "owner": return this.scopeOwnerLabelValue
      default: return scopeType
    }
  }

  async selectPreset(event) {
    if (event) event.preventDefault()
    const name = this.presetSelectTarget.value || "default"

    return this.withBusyStatus(async () => {
      const generation = this.lifecycleGeneration
      const response = await fetch(this.preferenceUrl(name), { headers: { "Accept": "application/json" } })
      if (!response.ok) throw new Error(`Failed to load table preference preset: ${response.status}`)
      const payload = await response.json()
      if (!this.lifecycleActive(generation)) return
      this.applyPreferencePayload(payload)
    }, {
      busyLabel: this.loadingStatusLabelValue,
      successLabel: this.loadedStatusLabelValue,
      errorLabel: this.loadingFailedStatusLabelValue
    })
  }

  applyPreferencePayload(payload) {
    this.nameValue = payload.name
    this.urlValue = this.preferenceUrl(payload.name)
    this.currentPreferenceEditable = payload.editable !== false
    this.setPresetNameInput(payload.name)
    this.setDefaultPresetInput(payload.default)
    this.settingsValue = this.mergeSettings(this.defaultSettings, payload.settings)
    this.closeFilterPanel()
    this.renderEditor()
    this.apply()
    this.broadcastSettingsSync()
    this.syncPresetEditingState()
  }

  syncPresetEditingState() {
    const editable = this.currentPreferenceEditable !== false
    if (this.hasDefaultPresetTarget) this.defaultPresetTarget.disabled = !editable
    if (this.hasReadOnlyHintTarget) {
      const showReadOnlyHint = !editable
      this.readOnlyHintTarget.hidden = !showReadOnlyHint
      this.readOnlyHintTarget.textContent = showReadOnlyHint ? this.readOnlyPresetHintLabelValue : ""
    }
    this.element.querySelectorAll("[data-action~='rails-table-preferences#saveFromEditor']").forEach((button) => {
      button.disabled = false
      button.dataset.railsTablePreferencesNonEditableFallback = editable ? "false" : "true"
    })
    this.element.querySelectorAll("[data-action~='rails-table-preferences#deletePreset']").forEach((button) => {
      button.disabled = !editable
      this.updateDeletePresetButtonContext(button)
    })
  }

  syncDeletePresetButtonContext() {
    this.element.querySelectorAll("[data-action~='rails-table-preferences#deletePreset']").forEach((button) => {
      this.updateDeletePresetButtonContext(button)
    })
  }

  updateDeletePresetButtonContext(button) {
    if (!button) return
    const message = this.deletePresetConfirmationMessage()
    const buttonLabel = button.textContent?.trim() || this.deleteConfirmLabelValue || "削除"
    button.title = message || buttonLabel
    button.setAttribute("aria-label", message ? `${buttonLabel}: ${message}` : buttonLabel)
  }

  setEditorRowsBusyState(busy) {
    if (!this.hasEditorRowsTarget) return
    this.editorRowsTarget.querySelectorAll("input, button, select, textarea").forEach((control) => {
      control.disabled = busy
    })
  }

  setTableInteractionBusyState(busy) {
    const table = this.tableElement
    if (!table) return
    this.headerCells.forEach((cell) => {
      if (cell.dataset.railsTablePreferencesTableDragInstalled === "true") cell.draggable = !busy
    })
    table.querySelectorAll("[data-rails-table-preferences-filter-button], [data-rails-table-preferences-resize-handle]").forEach((control) => {
      control.disabled = busy
    })
  }

  setBusyState(busy) {
    this.busy = busy === true
    if (this.busy) this.closeFilterPanel()
    if (this.hasPresetSelectTarget) this.presetSelectTarget.disabled = this.busy
    if (this.hasPresetNameTarget) this.presetNameTarget.disabled = this.busy
    if (this.hasDefaultPresetTarget) this.defaultPresetTarget.disabled = this.busy
    this.element.querySelectorAll(".rails-table-preferences-editor__actions button").forEach((button) => {
      button.disabled = this.busy
    })
    this.setEditorRowsBusyState(this.busy)
    this.setTableInteractionBusyState(this.busy)
    this.element.setAttribute("aria-busy", this.busy ? "true" : "false")
    if (!this.busy) this.syncPresetEditingState()
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message || ""
  }

  handleOperationError(error, message = this.operationFailedStatusLabelValue) {
    console.error(error)
    this.setStatus(message)
  }

  async withBusyStatus(callback, { busyLabel, successLabel, errorLabel = this.operationFailedStatusLabelValue } = {}) {
    if (this.busy) return null
    const generation = this.lifecycleGeneration
    this.partialSuccess = null
    this.setBusyState(true)
    if (busyLabel) this.setStatus(busyLabel)

    try {
      const result = await callback()
      if (!this.lifecycleActive(generation)) return null
      const partialSuccessMessage = this.partialSuccess?.generation === generation ? this.partialSuccess.message : null
      if (partialSuccessMessage) this.setStatus(partialSuccessMessage)
      else if (successLabel) this.setStatus(successLabel)
      return result
    } catch (error) {
      if (this.lifecycleActive(generation)) this.handleOperationError(error, errorLabel)
      return null
    } finally {
      if (this.lifecycleActive(generation)) this.setBusyState(false)
      if (this.partialSuccess?.generation === generation) this.partialSuccess = null
    }
  }

  renderEditor() {
    if (!this.hasEditorRowsTarget) return
    this.editorRowsTarget.innerHTML = ""
    this.columnsFromSettings.forEach((column) => this.editorRowsTarget.appendChild(this.buildEditorRow(column)))
    this.refreshEditorOrderInputs()
  }

  buildEditorRow(column) {
    const row = document.createElement("div")
    row.className = "rails-table-preferences-editor__row"
    row.classList.toggle("rails-table-preferences-editor__row--pinned", column.pinned === true)
    row.classList.toggle("rails-table-preferences-editor__row--fixed", column.pinned === true)
    row.draggable = true
    row.dataset.railsTablePreferencesColumnKey = column.key
    if (column.pinned === true) {
      row.dataset.railsTablePreferencesPinned = "true"
      row.dataset.railsTablePreferencesFixed = "true"
    }
    row.addEventListener("dragstart", this.dragEditorRowStart.bind(this))
    row.addEventListener("dragover", this.dragEditorRowOver.bind(this))
    row.addEventListener("drop", this.dropEditorRow.bind(this))
    row.addEventListener("dragend", this.dragEditorRowEnd.bind(this))
    row.innerHTML = `
      <button type="button" class="rails-table-preferences-editor__drag-handle" draggable="false" aria-label="${this.escapeHtml(this.dragLabelValue)}" title="${this.escapeHtml(this.dragLabelValue)}">↕</button>
      <label class="rails-table-preferences-editor__visible">
        <input type="checkbox" data-field="visible" ${column.visible === false ? "" : "checked"}>
        <span>${this.escapeHtml(column.label || column.key)}</span>
      </label>
      <label class="rails-table-preferences-editor__order">${this.escapeHtml(this.orderLabelValue)}<input type="number" min="1" data-field="order" value="${column.order ?? ""}" inputmode="numeric"></label>
      <label class="rails-table-preferences-editor__width">${this.escapeHtml(this.widthLabelValue)}<input type="number" min="1" data-field="width" value="${column.width ?? ""}" inputmode="numeric"></label>
      <label class="rails-table-preferences-editor__truncate">${this.escapeHtml(this.truncateLabelValue)}<input type="number" min="1" data-field="truncate" value="${column.truncate ?? ""}" inputmode="numeric"></label>
    `
    return row
  }

  dragEditorRowStart(event) {
    if (this.busy) {
      event.preventDefault()
      return
    }
    const row = event.currentTarget
    this.draggedEditorRow = row
    row.classList.add("rails-table-preferences-editor__row--dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", row.dataset.railsTablePreferencesColumnKey)
  }

  dragEditorRowOver(event) {
    if (this.busy) return
    event.preventDefault()
    const targetRow = event.currentTarget
    if (!this.draggedEditorRow || targetRow === this.draggedEditorRow) return
    const placement = this.editorRowPlacement(event, targetRow)
    if (placement === "before") this.editorRowsTarget.insertBefore(this.draggedEditorRow, targetRow)
    else this.editorRowsTarget.insertBefore(this.draggedEditorRow, targetRow.nextSibling)
    this.refreshEditorOrderInputs()
  }

  dropEditorRow(event) {
    if (this.busy) return
    event.preventDefault()
    this.refreshEditorOrderInputs()
  }

  dragEditorRowEnd(event) {
    event.currentTarget.classList.remove("rails-table-preferences-editor__row--dragging")
    this.draggedEditorRow = null
    this.refreshEditorOrderInputs()
  }

  editorRowPlacement(event, row) {
    const rect = row.getBoundingClientRect()
    const offset = event.clientY - rect.top
    const rows = this.editorRows
    const draggedIndex = rows.indexOf(this.draggedEditorRow)
    const targetIndex = rows.indexOf(row)
    if (draggedIndex >= 0 && targetIndex >= 0) {
      if (draggedIndex < targetIndex) return offset > rect.height * this.reorderActivationRatio ? "after" : "before"
      if (draggedIndex > targetIndex) return offset < rect.height * (1 - this.reorderActivationRatio) ? "before" : "after"
    }
    return offset < rect.height / 2 ? "before" : "after"
  }

  refreshEditorOrderInputs() {
    if (!this.hasEditorRowsTarget) return
    this.editorRows.forEach((row, index) => {
      const orderInput = row.querySelector('[data-field="order"]')
      if (orderInput) orderInput.value = String((index + 1) * 10)
    })
  }

  syncEditorWidthInputs() {
    if (!this.hasEditorRowsTarget) return
    this.editorRows.forEach((row) => {
      const column = this.columnByKey(row.dataset.railsTablePreferencesColumnKey)
      const widthInput = row.querySelector('[data-field="width"]')
      if (widthInput && column?.width) widthInput.value = String(column.width)
    })
  }

  installResizeHandles() {
    this.headerCells.forEach((cell) => {
      if (cell.querySelector("[data-rails-table-preferences-resize-handle]")) return
      const handle = document.createElement("button")
      handle.type = "button"
      handle.className = "rails-table-preferences-resize-handle"
      handle.dataset.railsTablePreferencesResizeHandle = "true"
      handle.setAttribute("aria-label", this.resizeHandleLabel(cell))
      handle.addEventListener("pointerdown", this.startColumnResize.bind(this))
      handle.addEventListener("dblclick", this.autoFitColumnFromHandle.bind(this))
      handle.addEventListener("click", (event) => event.preventDefault())
      this.applyResizeHandleHitArea(cell, handle)
      cell.appendChild(handle)
    })
  }

  resizeHandleLabel(cell) {
    const key = cell?.dataset.railsTablePreferencesColumnKey
    const label = this.visibleColumnLabelFor(cell, key)
    return label ? `${this.resizeLabelValue}: ${label}` : this.resizeLabelValue
  }

  visibleColumnLabelFor(cell, key) {
    const configuredLabel = this.columnDefinitionByKey(key)?.label || this.columnByKey(key)?.label
    if (configuredLabel) return configuredLabel
    const headerText = this.headerCellTextLabel(cell)
    return headerText || key || ""
  }

  headerCellTextLabel(cell) {
    if (!cell) return ""
    const clone = cell.cloneNode(true)
    clone.querySelectorAll("[data-rails-table-preferences-resize-handle], [data-rails-table-preferences-filter-button], [data-rails-table-preferences-sort-indicator]").forEach((node) => node.remove())
    return clone.textContent?.trim() || ""
  }

  applyResizeHandleHitArea(cell, handle) {
    if (window.getComputedStyle(cell).position === "static") cell.style.position = "relative"
    handle.style.position = "absolute"
    handle.style.top = "0"
    handle.style.right = "0"
    handle.style.bottom = "0"
    handle.style.width = `${this.normalizedResizeHandleWidth}px`
    handle.style.padding = "0"
    handle.style.border = "0"
    handle.style.background = "transparent"
    handle.style.cursor = "col-resize"
    handle.style.opacity = "0"
    handle.style.zIndex = "1"
    handle.style.touchAction = "none"
    handle.style.userSelect = "none"
  }

  startColumnResize(event) {
    if (event.button !== undefined && event.button !== 0) return
    event.preventDefault()
    event.stopPropagation()
    if (this.busy) return
    if (event.detail > 1) return
    const headerCell = event.currentTarget.closest("[data-rails-table-preferences-column-key]")
    if (!headerCell) return
    this.resizingColumn = {
      key: headerCell.dataset.railsTablePreferencesColumnKey,
      startX: event.clientX,
      startWidth: headerCell.getBoundingClientRect().width,
      pointerId: event.pointerId
    }
    this.boundResizeColumn = this.resizeColumn.bind(this)
    this.boundStopColumnResize = this.stopColumnResize.bind(this)
    document.addEventListener("pointermove", this.boundResizeColumn)
    document.addEventListener("pointerup", this.boundStopColumnResize)
    document.addEventListener("pointercancel", this.boundStopColumnResize)
  }

  resizeColumn(event) {
    if (this.busy || !this.resizingColumn) return
    const width = Math.max(40, Math.round(this.resizingColumn.startWidth + event.clientX - this.resizingColumn.startX))
    this.updateColumnSetting(this.resizingColumn.key, { width })
    this.applyColumn(this.columnByKey(this.resizingColumn.key))
    this.syncPinnedColumnOffsets()
    this.syncEditorWidthInputs()
  }

  stopColumnResize() {
    this.uninstallDocumentResizeListeners()
    this.resizingColumn = null
  }

  autoFitColumnFromHandle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.busy) return
    const headerCell = event.currentTarget.closest("[data-rails-table-preferences-column-key]")
    const key = headerCell?.dataset.railsTablePreferencesColumnKey
    if (!key) return
    this.uninstallDocumentResizeListeners()
    this.resizingColumn = null
    const width = this.autoFitWidthForColumn(key)
    if (!width) return
    this.updateColumnSetting(key, { width })
    this.applyColumn(this.columnByKey(key))
    this.syncPinnedColumnOffsets()
    this.syncEditorWidthInputs()
  }

  autoFitWidthForColumn(key) {
    const cells = Array.from(this.cellsFor(key)).filter((cell) => !cell.hidden && cell.offsetParent !== null)
    if (cells.length === 0) return null
    const measured = Math.max(...cells.map((cell) => this.measureAutoFitCellWidth(cell))) + this.normalizedResizeAutoFitPadding
    return Math.max(this.normalizedResizeAutoFitMinWidth, Math.min(this.normalizedResizeAutoFitMaxWidth, Math.ceil(measured)))
  }

  measureAutoFitCellWidth(cell) {
    const clone = cell.cloneNode(true)
    clone.querySelectorAll("[data-rails-table-preferences-resize-handle], [data-rails-table-preferences-filter-button], [data-rails-table-preferences-sort-indicator]").forEach((node) => node.remove())
    clone.style.position = "absolute"
    clone.style.visibility = "hidden"
    clone.style.left = "-10000px"
    clone.style.top = "0"
    clone.style.width = "auto"
    clone.style.maxWidth = "none"
    clone.style.minWidth = "0"
    clone.style.overflow = "visible"
    clone.style.textOverflow = "clip"
    clone.style.whiteSpace = "nowrap"
    clone.style.removeProperty("--rails-table-preferences-pinned-left")
    document.body.appendChild(clone)
    const width = Math.max(clone.scrollWidth, clone.getBoundingClientRect().width)
    clone.remove()
    return width
  }

  uninstallDocumentResizeListeners() {
    if (this.boundResizeColumn) document.removeEventListener("pointermove", this.boundResizeColumn)
    if (this.boundStopColumnResize) {
      document.removeEventListener("pointerup", this.boundStopColumnResize)
      document.removeEventListener("pointercancel", this.boundStopColumnResize)
    }
    this.boundResizeColumn = null
    this.boundStopColumnResize = null
  }

  installTableColumnDragHandles() {
    this.headerCells.forEach((cell) => {
      if (cell.dataset.railsTablePreferencesTableDragInstalled === "true") return
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
    if (this.busy) {
      event.preventDefault()
      return
    }
    if (this.shouldIgnoreHeaderAction(event.target)) {
      event.preventDefault()
      return
    }
    const headerCell = event.currentTarget
    this.draggedTableColumnKey = headerCell.dataset.railsTablePreferencesColumnKey
    headerCell.classList.add("rails-table-preferences-table-column--dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedTableColumnKey)
  }

  dragTableColumnOver(event) {
    if (this.busy || !this.draggedTableColumnKey) return
    if (this.shouldIgnoreHeaderAction(event.target)) return
    event.preventDefault()
    const targetKey = event.currentTarget.dataset.railsTablePreferencesColumnKey
    if (!targetKey || targetKey === this.draggedTableColumnKey) return
    const placement = this.tableColumnPlacement(event, event.currentTarget)
    this.moveColumnInSettings(this.draggedTableColumnKey, targetKey, placement)
    this.applyColumnOrder()
    this.syncPinnedColumnOffsets()
  }

  dropTableColumn(event) {
    if (this.busy) return
    event.preventDefault()
    this.refreshEditorFromSettings()
  }

  endTableColumnDrag(event) {
    event.currentTarget.classList.remove("rails-table-preferences-table-column--dragging")
    this.draggedTableColumnKey = null
    this.refreshEditorFromSettings()
  }

  tableColumnPlacement(event, cell) {
    const rect = cell.getBoundingClientRect()
    const offset = event.clientX - rect.left
    const columns = this.orderedColumnsFromSettings
    const draggedIndex = columns.findIndex((column) => column.key === this.draggedTableColumnKey)
    const targetIndex = columns.findIndex((column) => column.key === cell.dataset.railsTablePreferencesColumnKey)
    if (draggedIndex >= 0 && targetIndex >= 0) {
      if (draggedIndex < targetIndex) return offset > rect.width * this.reorderActivationRatio ? "after" : "before"
      if (draggedIndex > targetIndex) return offset < rect.width * (1 - this.reorderActivationRatio) ? "before" : "after"
    }
    return offset < rect.width / 2 ? "before" : "after"
  }

  moveColumnInSettings(draggedKey, targetKey, placement) {
    const columns = this.orderedColumnsFromSettings
    const draggedIndex = columns.findIndex((column) => column.key === draggedKey)
    const targetIndex = columns.findIndex((column) => column.key === targetKey)
    if (draggedIndex < 0 || targetIndex < 0) return
    const [draggedColumn] = columns.splice(draggedIndex, 1)
    const adjustedTargetIndex = columns.findIndex((column) => column.key === targetKey)
    columns.splice(placement === "before" ? adjustedTargetIndex : adjustedTargetIndex + 1, 0, draggedColumn)
    this.settingsValue = { ...this.settingsValue, columns: columns.map((column, index) => ({ ...column, order: (index + 1) * 10 })) }
  }

  installSortControls() {
    this.headerCells.forEach((cell) => {
      const key = cell.dataset.railsTablePreferencesColumnKey
      const column = this.columnDefinitionByKey(key)
      if (column?.sortable !== true) return
      if (cell.dataset.railsTablePreferencesSortInstalled === "true") return
      if (cell.hasAttribute("aria-description")) {
        cell.dataset.railsTablePreferencesHostAriaDescription = cell.getAttribute("aria-description") || ""
      }
      cell.dataset.railsTablePreferencesSortInstalled = "true"
      cell.classList.add("rails-table-preferences-sortable-column")
      cell.tabIndex = 0
      cell.addEventListener("click", (event) => this.toggleSortFromHeader(event, cell, column))
      cell.addEventListener("keydown", (event) => {
        if (!["Enter", " ", "Spacebar"].includes(event.key)) return
        this.toggleSortFromHeader(event, cell, column)
      })
      if (!cell.querySelector("[data-rails-table-preferences-sort-indicator]")) {
        const indicator = document.createElement("span")
        indicator.className = "rails-table-preferences-sort-indicator"
        indicator.dataset.railsTablePreferencesSortIndicator = "true"
        indicator.setAttribute("aria-hidden", "true")
        cell.appendChild(indicator)
      }
    })
    this.syncSortStates()
  }

  toggleSortFromHeader(event, cell, column) {
    if (this.busy) return
    if (column?.sortable !== true) return
    if (this.shouldIgnoreHeaderAction(event.target)) return
    if (this.draggedTableColumnKey || this.resizingColumn) return
    event.preventDefault()
    const sorts = this.settingsValue?.sorts || []
    const currentIndex = sorts.findIndex((sort) => sort.key === column.key)
    const current = currentIndex >= 0 ? sorts[currentIndex] : undefined
    let nextSorts
    if (!event.shiftKey) {
      if (!current) nextSorts = [{ key: column.key, direction: "asc" }]
      else if (current.direction === "asc") nextSorts = [{ key: column.key, direction: "desc" }]
      else nextSorts = []
    } else if (!current) {
      nextSorts = [...sorts, { key: column.key, direction: "asc" }]
    } else if (current.direction === "asc") {
      nextSorts = sorts.map((sort, index) => index === currentIndex ? { ...sort, direction: "desc" } : sort)
    } else {
      nextSorts = sorts.filter((_sort, index) => index !== currentIndex)
    }
    this.settingsValue = { ...this.settingsValue, sorts: nextSorts }
    this.syncSortStates()
  }

  syncSortStates() {
    const sorts = this.settingsValue?.sorts || []
    this.headerCells.forEach((cell) => {
      const key = cell.dataset.railsTablePreferencesColumnKey
      const sortIndex = sorts.findIndex((sort) => sort.key === key)
      const sort = sortIndex >= 0 ? sorts[sortIndex] : undefined
      const indicator = cell.querySelector("[data-rails-table-preferences-sort-indicator]")
      cell.classList.toggle("rails-table-preferences-sortable-column--sorted", Boolean(sort))
      if (cell.dataset.railsTablePreferencesSortInstalled === "true" && sortIndex === 0) {
        cell.setAttribute("aria-sort", sort.direction === "asc" ? "ascending" : "descending")
      } else {
        cell.removeAttribute("aria-sort")
      }
      if (cell.dataset.railsTablePreferencesSortInstalled === "true") {
        const hostDescription = cell.dataset.railsTablePreferencesHostAriaDescription
        if (sortIndex >= 0) {
          const priorityDescription = `${this.sortPriorityLabelValue}: ${sortIndex + 1}`
          cell.setAttribute("aria-description", hostDescription ? `${hostDescription}; ${priorityDescription}` : priorityDescription)
        } else if (hostDescription !== undefined) {
          cell.setAttribute("aria-description", hostDescription)
        } else {
          cell.removeAttribute("aria-description")
        }
      }
      if (indicator) indicator.textContent = sort?.direction === "asc" ? "▲" : sort?.direction === "desc" ? "▼" : ""
      if (cell.dataset.railsTablePreferencesSortInstalled === "true") {
        const label = sort?.direction === "asc" ? this.sortDescLabelValue : sort?.direction === "desc" ? this.sortClearLabelValue : this.sortAscLabelValue
        cell.title = sortIndex >= 0 ? `${label} (${this.sortPriorityLabelValue}: ${sortIndex + 1})` : label
      }
    })
  }

  sortFor(key) {
    return (this.settingsValue?.sorts || []).find((sort) => sort.key === key)
  }

  shouldIgnoreHeaderAction(target) {
    return Boolean(
      target.closest("[data-rails-table-preferences-resize-handle]") ||
      target.closest("[data-rails-table-preferences-filter-button]") ||
      target.closest("button") ||
      target.closest("input") ||
      target.closest("select") ||
      target.closest("textarea")
    )
  }

  installFilterControls() {
    this.headerCells.forEach((cell) => {
      const key = cell.dataset.railsTablePreferencesColumnKey
      const column = this.columnDefinitionByKey(key)
      if (!column?.filter) return
      if (cell.querySelector("[data-rails-table-preferences-filter-button]")) return
      const button = document.createElement("button")
      button.type = "button"
      button.className = "rails-table-preferences-filter-button"
      button.dataset.railsTablePreferencesFilterButton = "true"
      button.dataset.railsTablePreferencesColumnKey = key
      const buttonLabel = this.filterButtonLabel(column, this.filterConditionFor(key))
      button.setAttribute("aria-label", buttonLabel)
      button.setAttribute("aria-expanded", "false")
      button.title = buttonLabel
      button.textContent = "▾"
      button.addEventListener("mousedown", (event) => event.stopPropagation())
      button.addEventListener("dragstart", (event) => event.preventDefault())
      button.addEventListener("click", (event) => this.toggleFilterPanel(event, cell, column))
      cell.appendChild(button)
    })
    this.syncFilterButtonStates()
  }

  toggleFilterPanel(event, headerCell, column) {
    if (this.busy) return
    event.preventDefault()
    event.stopPropagation()
    if (this.filterPanel?.dataset.railsTablePreferencesColumnKey === column.key) this.closeFilterPanel()
    else this.openFilterPanel(headerCell, column, event.currentTarget)
  }

  openFilterPanel(headerCell, column, button = headerCell.querySelector("[data-rails-table-preferences-filter-button]")) {
    if (this.busy) return
    this.closeFilterPanel()
    const panel = document.createElement("div")
    panel.className = "rails-table-preferences-filter-panel"
    panel.id = this.filterPanelId(column.key)
    panel.dataset.railsTablePreferencesColumnKey = column.key
    panel.__railsTablePreferencesDraftCondition = this.filterDraftConditionFor(column.key)
    panel.innerHTML = this.filterPanelHtml(column)
    panel.querySelector("[data-field='operator']")?.addEventListener("change", () => {
      this.syncFilterPanelDraftCondition(panel)
      this.renderFilterPanelValueFields(panel, column)
      this.focusFilterPanelValueField(panel)
    })
    panel.querySelector("[data-action='apply-filter']")?.addEventListener("click", (event) => {
      event.preventDefault()
      this.applyFilterPanel(column.key, panel)
    })
    panel.querySelector("[data-action='clear-filter']")?.addEventListener("click", (event) => {
      event.preventDefault()
      this.clearFilter(column.key)
    })
    panel.addEventListener("input", () => this.syncFilterPanelDraftCondition(panel))
    panel.addEventListener("change", () => this.syncFilterPanelDraftCondition(panel))
    panel.addEventListener("click", (event) => event.stopPropagation())
    document.body.appendChild(panel)
    this.positionFilterPanel(panel, headerCell)
    this.filterPanel = panel
    this.filterPanelButton = button
    this.filterPanelHeaderCell = headerCell
    if (button) {
      button.setAttribute("aria-controls", panel.id)
      button.setAttribute("aria-expanded", "true")
    }
    this.boundCloseFilterPanel = (event) => {
      if (!panel.contains(event.target) && !event.target.closest("[data-rails-table-preferences-filter-button]")) this.closeFilterPanel()
    }
    this.boundCloseFilterPanelOnScroll = () => this.closeFilterPanel()
    this.boundCloseFilterPanelOnResize = () => this.closeFilterPanel()
    this.boundHandleFilterPanelKeydown = this.handleFilterPanelKeydown.bind(this)
    document.addEventListener("click", this.boundCloseFilterPanel)
    document.addEventListener("scroll", this.boundCloseFilterPanelOnScroll, true)
    window.addEventListener("resize", this.boundCloseFilterPanelOnResize)
    panel.addEventListener("keydown", this.boundHandleFilterPanelKeydown)
    this.focusInitialFilterPanelField(panel)
    this.syncFilterButtonExpandedStates()
  }

  filterPanelHtml(column) {
    const filter = column.filter || {}
    const condition = this.filterConditionFor(column.key)
    const operators = this.filterOperatorsFor(filter)
    const requestedOperator = condition.operator || operators[0] || "contains"
    const selectedOperator = operators.includes(requestedOperator) ? requestedOperator : (operators[0] || "contains")
    return `
      <div class="rails-table-preferences-filter-panel__title">${this.escapeHtml(column.label || column.key)}</div>
      <label class="rails-table-preferences-filter-panel__field">
        ${this.escapeHtml(this.filterOperatorLabelValue)}
        <select data-field="operator">
          ${operators.map((operator) => `<option value="${this.escapeHtml(operator)}" ${operator === selectedOperator ? "selected" : ""}>${this.escapeHtml(this.filterOperatorText(operator))}</option>`).join("")}
        </select>
      </label>
      <div data-rails-table-preferences-filter-values="true">
        ${this.filterValueHtml(filter, condition, selectedOperator)}
      </div>
      <div class="rails-table-preferences-filter-panel__actions">
        <button type="button" data-action="apply-filter">${this.escapeHtml(this.filterApplyLabelValue)}</button>
        <button type="button" data-action="clear-filter">${this.escapeHtml(this.filterClearLabelValue)}</button>
      </div>
    `
  }

  filterValueHtml(filter, condition, selectedOperator) {
    if (["blank", "present", "true", "false"].includes(selectedOperator)) return ""
    if (selectedOperator === "between") {
      return `
        <label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterFromLabelValue)}<input type="${this.filterInputType(filter)}" data-field="from" value="${this.escapeHtml(condition.from ?? "")}"></label>
        <label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterToLabelValue)}<input type="${this.filterInputType(filter)}" data-field="to" value="${this.escapeHtml(condition.to ?? "")}"></label>
      `
    }
    if (filter.type === "select" && Array.isArray(filter.options)) {
      const values = new Set(Array(condition.values || condition.value || []).map(String))
      return `<label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterValueLabelValue)}<select data-field="values" multiple>${filter.options.map((option) => `<option value="${this.escapeHtml(option)}" ${values.has(String(option)) ? "selected" : ""}>${this.escapeHtml(option)}</option>`).join("")}</select></label>`
    }
    return `<label class="rails-table-preferences-filter-panel__field">${this.escapeHtml(this.filterValueLabelValue)}<input type="${this.filterInputType(filter)}" data-field="value" value="${this.escapeHtml(condition.value ?? "")}"></label>`
  }

  renderFilterPanelValueFields(panel, column) {
    const valuesContainer = panel.querySelector("[data-rails-table-preferences-filter-values]")
    if (!valuesContainer) return
    const draftCondition = panel.__railsTablePreferencesDraftCondition || this.filterDraftConditionFor(column.key)
    const operator = panel.querySelector("[data-field='operator']")?.value || draftCondition.operator || this.filterOperatorsFor(column.filter || {})[0] || "contains"
    draftCondition.operator = operator
    panel.__railsTablePreferencesDraftCondition = draftCondition
    valuesContainer.innerHTML = this.filterValueHtml(column.filter || {}, draftCondition, operator)
  }

  filterDraftConditionFor(key) {
    const condition = this.filterConditionFor(key)
    return {
      operator: String(condition.operator || ""),
      value: condition.value ?? "",
      values: Array.isArray(condition.values) ? condition.values.map(String) : [],
      from: condition.from ?? "",
      to: condition.to ?? ""
    }
  }

  syncFilterPanelDraftCondition(panel) {
    const draftCondition = panel.__railsTablePreferencesDraftCondition || { value: "", values: [], from: "", to: "" }
    draftCondition.operator = panel.querySelector("[data-field='operator']")?.value || draftCondition.operator || ""

    const valueInput = panel.querySelector("[data-field='value']")
    draftCondition.value = valueInput ? valueInput.value : ""

    const valuesSelect = panel.querySelector("[data-field='values']")
    draftCondition.values = valuesSelect ? Array.from(valuesSelect.selectedOptions).map((option) => option.value) : []

    const fromInput = panel.querySelector("[data-field='from']")
    draftCondition.from = fromInput ? fromInput.value : ""

    const toInput = panel.querySelector("[data-field='to']")
    draftCondition.to = toInput ? toInput.value : ""

    panel.__railsTablePreferencesDraftCondition = draftCondition
    return draftCondition
  }

  positionFilterPanel(panel, headerCell) {
    const rect = headerCell.getBoundingClientRect()
    panel.style.position = "absolute"
    panel.style.top = `${window.scrollY + rect.bottom + 4}px`
    panel.style.left = `${window.scrollX + rect.left}px`
    panel.style.zIndex = "1000"
  }

  focusInitialFilterPanelField(panel) {
    const firstField = panel.querySelector("[data-field='operator']") ||
      panel.querySelector("[data-field='value'], [data-field='from'], [data-field='values']")
    firstField?.focus()
  }

  focusFilterPanelValueField(panel) {
    const firstField = panel.querySelector("[data-field='value'], [data-field='from'], [data-field='values']") ||
      panel.querySelector("[data-action='apply-filter']")
    firstField?.focus()
  }

  handleFilterPanelKeydown(event) {
    if (event.key !== "Escape") return
    event.preventDefault()
    event.stopPropagation()
    this.closeFilterPanel({ returnFocus: true })
  }

  filterPanelId(columnKey) {
    const tableKey = this.filterPanelIdSegment(this.tableKeyValue, "table")
    const normalizedColumnKey = this.filterPanelIdSegment(columnKey, "column")
    return `rails-table-preferences-filter-panel-${tableKey}-${this.filterPanelInstanceId}-${normalizedColumnKey}`
  }

  filterPanelIdSegment(value, fallback) {
    const text = String(value || fallback)
    const encoded = encodeURIComponent(text)
    return `${encoded.length}_${encoded}`
  }

  applyFilterPanel(key, panel) {
    if (this.busy) return
    const draftCondition = this.syncFilterPanelDraftCondition(panel)
    const operator = draftCondition.operator
    if (!operator) return
    const condition = { operator }
    if (operator === "between") {
      if (draftCondition.from) condition.from = draftCondition.from
      if (draftCondition.to) condition.to = draftCondition.to
    } else if (!["blank", "present", "true", "false"].includes(operator)) {
      if (Array.isArray(draftCondition.values) && draftCondition.values.length > 0) condition.values = draftCondition.values
      else if (draftCondition.value) condition.value = draftCondition.value
    }
    this.updateFilterCondition(key, condition)
    this.closeFilterPanel({ returnFocus: true })
    this.apply()
  }

  clearFilter(key) {
    if (this.busy) return
    const filters = { ...(this.settingsValue?.filters || {}) }
    delete filters[key]
    this.settingsValue = { ...this.settingsValue, filters }
    this.closeFilterPanel({ returnFocus: true })
    this.apply()
  }

  updateFilterCondition(key, condition) {
    this.settingsValue = { ...this.settingsValue, filters: { ...(this.settingsValue?.filters || {}), [key]: condition } }
  }

  closeFilterPanel({ returnFocus = false } = {}) {
    if (this.boundCloseFilterPanel) document.removeEventListener("click", this.boundCloseFilterPanel)
    if (this.boundCloseFilterPanelOnScroll) document.removeEventListener("scroll", this.boundCloseFilterPanelOnScroll, true)
    if (this.boundCloseFilterPanelOnResize) window.removeEventListener("resize", this.boundCloseFilterPanelOnResize)
    if (this.boundHandleFilterPanelKeydown && this.filterPanel) this.filterPanel.removeEventListener("keydown", this.boundHandleFilterPanelKeydown)
    this.boundCloseFilterPanel = null
    this.boundCloseFilterPanelOnScroll = null
    this.boundCloseFilterPanelOnResize = null
    this.boundHandleFilterPanelKeydown = null
    const button = this.filterPanelButton
    if (this.filterPanel) this.filterPanel.remove()
    this.filterPanel = null
    this.filterPanelHeaderCell = null
    this.filterPanelButton = null
    this.syncFilterButtonExpandedStates()
    if (returnFocus && button) button.focus()
  }

  syncFilterButtonStates() {
    this.headerCells.forEach((cell) => {
      const key = cell.dataset.railsTablePreferencesColumnKey
      const button = cell.querySelector("[data-rails-table-preferences-filter-button]")
      if (!button) return
      const condition = this.filterConditionFor(key)
      const active = condition.operator
      button.classList.toggle("rails-table-preferences-filter-button--active", Boolean(active))
      button.setAttribute("aria-pressed", active ? "true" : "false")
      const label = this.filterButtonLabel(this.columnDefinitionByKey(key) || { key }, condition)
      button.setAttribute("aria-label", label)
      button.title = label
    })
    this.syncFilterButtonExpandedStates()
  }

  syncFilterButtonExpandedStates() {
    const openKey = this.filterPanel?.dataset.railsTablePreferencesColumnKey
    this.headerCells.forEach((cell) => {
      const button = cell.querySelector("[data-rails-table-preferences-filter-button]")
      if (!button) return
      const expanded = openKey && cell.dataset.railsTablePreferencesColumnKey === openKey
      button.setAttribute("aria-expanded", expanded ? "true" : "false")
      if (!expanded) button.removeAttribute("aria-controls")
    })
  }

  filterButtonLabel(column, condition = {}) {
    const columnLabel = column?.label || column?.key || this.filterLabelValue
    const baseLabel = `${this.filterLabelValue}: ${columnLabel}`
    const summary = this.filterConditionSummary(condition)
    return summary ? `${baseLabel} (${summary})` : baseLabel
  }

  filterConditionSummary(condition = {}) {
    const operator = String(condition?.operator || "").trim()
    if (!operator) return ""
    const operatorText = this.filterOperatorText(operator)
    if (operator === "between") {
      const from = this.filterSummaryText(condition.from)
      const to = this.filterSummaryText(condition.to)
      if (from && to) return `${operatorText}: ${from} - ${to}`
      if (from) return `${operatorText}: ${this.filterFromLabelValue} ${from}`
      if (to) return `${operatorText}: ${this.filterToLabelValue} ${to}`
      return operatorText
    }
    if (["blank", "present", "true", "false"].includes(operator)) return operatorText
    const values = Array.isArray(condition.values) ? condition.values.map((value) => this.filterSummaryText(value)).filter(Boolean) : []
    if (values.length > 0) return `${operatorText}: ${this.filterSummaryValues(values)}`
    const value = this.filterSummaryText(condition.value)
    return value ? `${operatorText}: ${value}` : operatorText
  }

  filterSummaryValues(values) {
    if (values.length <= 2) return values.join(", ")
    return `${values.slice(0, 2).join(", ")} +${values.length - 2}`
  }

  filterSummaryText(value) {
    const text = String(value ?? "").trim()
    if (!text) return ""
    return text.length > 24 ? `${text.slice(0, 21)}...` : text
  }

  filterConditionFor(key) {
    return this.settingsValue?.filters?.[key] || {}
  }

  filterOperatorsFor(filter) {
    if (Array.isArray(filter.operators) && filter.operators.length > 0) return filter.operators.map(String)
    switch (filter.type) {
      case "number": return ["equals", "gteq", "lteq", "gt", "lt", "blank", "present"]
      case "date": return ["equals", "gteq", "lteq", "between", "blank", "present"]
      case "select": return ["in", "not_in", "blank", "present"]
      case "boolean": return ["true", "false", "blank", "present"]
      default: return ["contains", "equals", "starts_with", "ends_with", "blank", "present"]
    }
  }

  filterInputType(filter) {
    if (filter.type === "number") return "number"
    if (filter.type === "date") return "date"
    return "text"
  }

  filterOperatorText(operator) {
    const labels = { contains: "含む", not_contains: "含まない", equals: "一致", not_equals: "不一致", starts_with: "で始まる", ends_with: "で終わる", in: "いずれか", not_in: "以外", gt: "より大きい", gteq: "以上", lt: "より小さい", lteq: "以下", between: "範囲", blank: "空白", present: "空白以外", true: "はい", false: "いいえ" }
    return labels[operator] || operator
  }

  refreshEditorFromSettings() {
    this.renderEditor()
    this.syncEditorWidthInputs()
    this.syncPinnedColumnOffsets()
    this.syncFilterButtonStates()
    this.syncSortStates()
  }

  settingsFromEditor() {
    if (!this.hasEditorRowsTarget) return this.settingsValue
    const columns = this.editorRows.map((row, index) => {
      const key = row.dataset.railsTablePreferencesColumnKey
      const current = this.columnByKey(key) || {}
      return {
        key,
        visible: row.querySelector('[data-field="visible"]')?.checked ?? true,
        order: this.positiveIntegerValue(row.querySelector('[data-field="order"]')?.value) ?? this.positiveIntegerValue(current.order) ?? (index + 1) * 10,
        width: this.positiveIntegerValue(row.querySelector('[data-field="width"]')?.value),
        truncate: this.positiveIntegerValue(row.querySelector('[data-field="truncate"]')?.value),
        pinned: current.pinned === true
      }
    })
    return { ...this.settingsValue, columns, filters: this.settingsValue?.filters || {}, sorts: this.settingsValue?.sorts || [] }
  }

  applyColumn(column) {
    if (!column) return
    this.cellsFor(column.key).forEach((cell) => {
      cell.hidden = column.visible === false
      cell.style.width = ""
      cell.style.maxWidth = ""
      cell.style.overflow = ""
      cell.style.textOverflow = ""
      cell.style.whiteSpace = ""
      cell.style.removeProperty("--rails-table-preferences-pinned-left")
      cell.classList.toggle("rails-table-preferences-pinned", column.pinned === true)
      cell.classList.toggle("rails-table-preferences-fixed", column.pinned === true)
      if (column.pinned === true) {
        cell.dataset.railsTablePreferencesPinned = "true"
        cell.dataset.railsTablePreferencesFixed = "true"
      } else {
        delete cell.dataset.railsTablePreferencesPinned
        delete cell.dataset.railsTablePreferencesFixed
      }
      delete cell.dataset.railsTablePreferencesTruncate
      delete cell.dataset.railsTablePreferencesOverflow
      if (cell.dataset.railsTablePreferencesAutoTitle === "true") {
        cell.removeAttribute("title")
        delete cell.dataset.railsTablePreferencesAutoTitle
      }
      if (column.width) {
        cell.style.width = `${column.width}px`
        cell.style.maxWidth = `${column.width}px`
      }
      if (column.truncate) {
        cell.dataset.railsTablePreferencesTruncate = column.truncate
      }
      this.applyColumnOverflow(cell, column)
    })
  }

  applyColumnOverflow(cell, column) {
    const overflow = column.overflow || (column.truncate ? "ellipsis" : null)
    if (!overflow) return
    cell.dataset.railsTablePreferencesOverflow = overflow
    switch (overflow) {
      case "wrap":
        cell.style.overflow = "visible"
        cell.style.textOverflow = "clip"
        cell.style.whiteSpace = "normal"
        break
      case "clip":
        cell.style.overflow = "hidden"
        cell.style.textOverflow = "clip"
        cell.style.whiteSpace = "nowrap"
        break
      case "nowrap":
        cell.style.overflow = "visible"
        cell.style.textOverflow = "clip"
        cell.style.whiteSpace = "nowrap"
        break
      default:
        cell.style.overflow = "hidden"
        cell.style.textOverflow = "ellipsis"
        cell.style.whiteSpace = "nowrap"
        if (!cell.title) {
          cell.title = cell.textContent.trim()
          cell.dataset.railsTablePreferencesAutoTitle = "true"
        }
    }
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
      left += column.width || Math.round(firstVisibleCell?.getBoundingClientRect().width || 0)
    })
  }

  applyColumnOrder() {
    const orderedKeys = this.orderedColumnsFromSettings.map((column) => column.key)
    this.tableRows.forEach((row) => {
      const keyedCells = new Map(Array.from(row.children).filter((cell) => cell.dataset.railsTablePreferencesColumnKey).map((cell) => [cell.dataset.railsTablePreferencesColumnKey, cell]))
      orderedKeys.forEach((key) => {
        const cell = keyedCells.get(key)
        if (cell) row.appendChild(cell)
      })
    })
  }

  buildDefaultSettings() {
    return {
      columns: this.columnsValue.map((column, index) => ({ key: column.key, label: column.label || column.key, visible: column.visible !== false, order: column.order ?? (index + 1) * 10, width: column.width, truncate: column.truncate, overflow: column.overflow, pinned: column.pinned === true, filter: column.filter, sortable: column.sortable })),
      filters: {},
      sorts: []
    }
  }

  mergeSettings(defaultSettings, savedSettings) {
    const savedColumns = new Map((savedSettings?.columns || []).map((column) => [column.key, column]))
    const columns = defaultSettings.columns.map((defaultColumn, index) => {
      const savedColumn = savedColumns.get(defaultColumn.key) || {}
      return { ...defaultColumn, ...savedColumn, label: defaultColumn.label, filter: defaultColumn.filter, sortable: defaultColumn.sortable, overflow: defaultColumn.overflow, pinned: defaultColumn.pinned, order: savedColumn.order ?? defaultColumn.order ?? (index + 1) * 10, visible: savedColumn.visible ?? defaultColumn.visible }
    })
    return { columns, filters: savedSettings?.filters || {}, sorts: savedSettings?.sorts || [] }
  }

  updateColumnSetting(key, attributes) {
    this.settingsValue = { ...this.settingsValue, columns: this.columnsFromSettings.map((column) => column.key === key ? { ...column, ...attributes } : column) }
  }

  preferenceUrl(name) {
    return `${this.collectionUrlValue}/${encodeURIComponent(name || "default")}`
  }

  confirmDeletePreset() {
    const message = this.deletePresetConfirmationMessage()
    if (!message) return true
    if (typeof window === "undefined" || typeof window.confirm !== "function") return true
    return window.confirm(message)
  }

  deletePresetConfirmationMessage() {
    const message = this.deleteConfirmLabelValue?.trim()
    const displayName = this.currentDeletePresetDisplayName
    if (!displayName) return message
    if (!message) return displayName
    return `${message}\n\n${displayName}`
  }

  setPresetNameInput(name) {
    if (this.hasPresetNameTarget) this.presetNameTarget.value = name
  }

  setDefaultPresetInput(value) {
    if (this.hasDefaultPresetTarget) this.defaultPresetTarget.checked = value === true
  }

  cellsFor(key) {
    const table = this.tableElement
    if (!table) return []
    return table.querySelectorAll(`[data-rails-table-preferences-column-key="${this.escapeSelectorValue(key)}"]`)
  }

  columnByKey(key) {
    return this.columnsFromSettings.find((column) => column.key === key)
  }

  columnDefinitionByKey(key) {
    return this.columnsValue.find((column) => column.key === key) || this.columnByKey(key)
  }

  normalizedPresetOptionText(option) {
    return option?.textContent?.replace(/\s+\*$/, "").trim() || ""
  }

  orderValue(column) {
    return Number.isFinite(Number(column.order)) ? Number(column.order) : Number.MAX_SAFE_INTEGER
  }

  positiveIntegerValue(value) {
    const integer = this.integerValue(value)
    return integer !== null && integer > 0 ? integer : null
  }

  integerValue(value) {
    if (value === undefined || value === null) return null
    const text = String(value).trim()
    if (!/^-?\d+$/.test(text)) return null
    const integer = Number(text)
    return Number.isSafeInteger(integer) ? integer : null
  }

  escapeHtml(value) {
    const span = document.createElement("span")
    span.textContent = value
    return span.innerHTML
  }

  escapeSelectorValue(value) {
    if (typeof CSS !== "undefined" && typeof CSS.escape === "function") return CSS.escape(String(value))
    return String(value).replace(/["\\]/g, "\\$&")
  }

  get columnsFromSettings() { return this.settingsValue?.columns || [] }
  get orderedColumnsFromSettings() { return this.columnsFromSettings.slice().sort((left, right) => this.orderValue(left) - this.orderValue(right)) }
  get normalizedResizeHandleWidth() { const value = Number(this.resizeHandleWidthValue); return Number.isFinite(value) && value > 0 ? value : 10 }
  get normalizedResizeAutoFitPadding() { const value = Number(this.resizeAutoFitPaddingValue); return Number.isFinite(value) && value >= 0 ? value : 24 }
  get normalizedResizeAutoFitMinWidth() { const value = Number(this.resizeAutoFitMinWidthValue); return Number.isFinite(value) && value > 0 ? value : 40 }
  get normalizedResizeAutoFitMaxWidth() { const value = Number(this.resizeAutoFitMaxWidthValue); return Number.isFinite(value) && value > 0 ? value : 640 }
  get normalizedReorderSensitivity() { const value = Number(this.reorderSensitivityValue); return Number.isFinite(value) && value > 0 ? value : 1 }
  get reorderActivationRatio() { return Math.max(0.25, Math.min(0.5, 0.5 / this.normalizedReorderSensitivity)) }
  get currentPresetName() { return this.hasPresetNameTarget ? (this.presetNameTarget.value.trim() || "default") : (this.nameValue || "default") }
  get currentDeletePresetDisplayName() {
    const selectedOption = this.hasPresetSelectTarget ? this.presetSelectTarget.selectedOptions?.[0] : null
    if (selectedOption && selectedOption.value === this.currentPresetName) {
      return this.normalizedPresetOptionText(selectedOption)
    }
    return this.currentPresetName
  }
  get defaultPresetChecked() { return this.hasDefaultPresetTarget ? this.defaultPresetTarget.checked : false }
  get editorRows() { return this.hasEditorRowsTarget ? Array.from(this.editorRowsTarget.querySelectorAll("[data-rails-table-preferences-column-key]")) : [] }
  get tableElement() { return this.element.tagName === "TABLE" ? this.element : this.element.querySelector("table") }
  get headerCells() { const table = this.tableElement; return table ? Array.from(table.querySelectorAll("th[data-rails-table-preferences-column-key]")) : [] }
  get tableRows() { const table = this.tableElement; return table ? table.querySelectorAll("tr") : [] }
  get jsonHeaders() { return { "Accept": "application/json", "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken } }
  get csrfToken() { return document.querySelector("meta[name='csrf-token']")?.content || "" }
}