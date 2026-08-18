# frozen_string_literal: true

RSpec.describe "docs-portal column layout sync" do
  let(:source) do
    File.read(File.expand_path("../../app/javascript/rails_table_preferences/preset_select_recovery.js", __dir__)).gsub(/\r\n?/, "\n")
  end

  it "uses the existing settings-sync channel for column layout updates" do
    expect(source).to include('const settingsSyncEventName = "rails-table-preferences:settings-sync"')
    expect(source).to include('const columnLayoutSyncMode = "column-layout"')
    expect(source).to include('syncMode: columnLayoutSyncMode')
  end

  it "accepts column layout sync on editor-only roots with the same table key" do
    expect(source).to include(<<~JS)
      receiveSettingsSync(event) {
        const detail = event.detail || {}
        if (detail.syncMode !== columnLayoutSyncMode) return super.receiveSettingsSync(event)
        if (!this.connected || event.target === this.element) return
        if (String(detail.tableKey) !== String(this.tableKeyValue)) return
    JS
    expect(source).not_to include('detail.syncMode === columnLayoutSyncMode && !this.tableElement')
  end

  it "merges only width and order into the receiver draft" do
    expect(source).to include('order: source.order ?? column.order')
    expect(source).to include('width: source.width ?? column.width')
    expect(source).to include('return { ...currentSettings, columns }')
    expect(source).not_to include('visible: source.visible ?? column.visible')
    expect(source).not_to include('truncate: source.truncate ?? column.truncate')
  end

  it "broadcasts layout changes after resize, auto-fit, and table drag completion" do
    expect(source).to include(<<~JS)
      stopColumnResize() {
        const hadActiveResize = Boolean(this.resizingColumn)
        const result = super.stopColumnResize()
        if (hadActiveResize) this.broadcastColumnLayoutSync()
    JS
    expect(source).to include('if (previous !== this.stateChangeFingerprint()) this.broadcastColumnLayoutSync()')
    expect(source).to include(<<~JS)
      endTableColumnDrag(event) {
        const hadActiveDrag = Boolean(this.draggedTableColumnKey)
        const result = super.endTableColumnDrag(event)
        if (hadActiveDrag) this.broadcastColumnLayoutSync()
    JS
  end
end
