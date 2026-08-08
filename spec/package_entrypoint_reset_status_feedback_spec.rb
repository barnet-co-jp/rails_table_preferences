# frozen_string_literal: true

require "spec_helper"

RSpec.describe "package entrypoint reset status feedback" do
  let(:controller_source_path) do
    File.expand_path("../app/javascript/rails_table_preferences/controller.js", __dir__)
  end

  let(:base_controller_source_path) do
    File.expand_path("../app/javascript/controllers/rails_table_preferences_controller.js", __dir__)
  end

  let(:controller_source) { File.read(controller_source_path) }
  let(:base_controller_source) { File.read(base_controller_source_path) }

  it "uses the existing reset status value when reset completes" do
    reset_body = controller_source.match(/\n\s+resetEditor\(event\) \{(?<body>.*?)\n\s+\}\n\n\s+renderEditor/m)&.[](:body)

    expect(reset_body).not_to be_nil
    expect(controller_source).to include('resetStatusLabel: { type: String, default: "テーブル初期設定に戻しました。" }')
    expect(reset_body).to include("const result = super.resetEditor(event)")
    expect(reset_body).to include('this.setStatus(this.resetStatusLabelValue, "success")')
    expect(reset_body).to include('this.dispatchPreferenceEvent("applied", { action: "reset" })')
  end

  it "keeps base reset scoped to default settings without changing persistence" do
    reset_body = base_controller_source.match(/\n\s+resetEditor\(event\) \{(?<body>.*?)\n\s+\}\n\n\s+async loadPresets/m)&.[](:body)

    expect(reset_body).not_to be_nil
    expect(reset_body).to include("this.settingsValue = this.defaultSettings")
    expect(reset_body).to include("this.closeFilterPanel()")
    expect(reset_body).to include("this.renderEditor()")
    expect(reset_body).to include("this.apply()")
    expect(reset_body).to include("this.setStatus(this.resetStatusLabelValue)")
    expect(reset_body).not_to include("fetch(")
    expect(reset_body).not_to include("this.save")
  end
end
