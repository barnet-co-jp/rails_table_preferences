# frozen_string_literal: true

RSpec.describe "biz-ops RTP regression guardrails" do
  let(:controller_source) do
    File.read(File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__)).gsub(/\r\n?/, "\n").gsub(/^  /, "")
  end

  let(:stylesheet_source) do
    File.read(File.expand_path("../../app/assets/stylesheets/rails_table_preferences.css", __dir__)).gsub(/\r\n?/, "\n")
  end

  it "skips connect-time preset loading busy state when the preset select target is absent" do
    expect(controller_source).to include(<<~JS)
      async refreshPresetOptionsOnConnect() {
        if (!this.hasPresetSelectTarget) return null

        return this.withBusyStatus(async () => {
    JS
  end

  it "removes aria-busy when busy state ends" do
    expect(controller_source).to include('if (this.busy) this.element.setAttribute("aria-busy", "true")')
    expect(controller_source).to include('else this.element.removeAttribute("aria-busy")')
    expect(controller_source).not_to include('this.element.setAttribute("aria-busy", this.busy ? "true" : "false")')
  end

  it "keeps the grab cursor when a header is both draggable and sortable" do
    expect(stylesheet_source).to include(<<~CSS)
      .rails-table-preferences-table-column-draggable,
      .rails-table-preferences-table-column-draggable.rails-table-preferences-sortable-column {
        cursor: grab;
      }
    CSS
  end
end
