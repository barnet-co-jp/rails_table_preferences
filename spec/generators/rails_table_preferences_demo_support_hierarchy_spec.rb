# frozen_string_literal: true

require "spec_helper"

RSpec.describe "generated demo support section hierarchy" do
  let(:template_source) do
    File.read(
      File.expand_path(
        "../../lib/generators/rails_table_preferences/install/templates/demo/index.html.erb",
        __dir__
      )
    )
  end

  it "keeps secondary verification blocks behind collapsible summaries" do
    expect(template_source).to include('<details class="rails-table-preferences-demo-summary rails-table-preferences-demo-support-details"')
    expect(template_source).to include('<summary>検索フォーム hidden fields プレビュー</summary>')
    expect(template_source).to include('<summary>export payload プレビュー</summary>')
    expect(template_source).to include('<summary>デモ状態リセット</summary>')
    expect(template_source).to include('<summary>非同期失敗チェック</summary>')
  end

  it "preserves existing support evidence payloads and demo-only actions" do
    expect(template_source).to include('@export_payload_preview.fetch("export_keys", [])')
    expect(template_source).to include('export_payload_with_hidden_preview.fetch("export_keys", [])')
    expect(template_source).to include('data-rails-table-preferences-demo-reset-trigger')
    expect(template_source).to include('data-rails-table-preferences-demo-failure-trigger')
  end
end
