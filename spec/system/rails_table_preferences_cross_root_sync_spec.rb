# frozen_string_literal: true

require "spec_helper"

class RailsTablePreferencesCrossRootSyncController < ApplicationController
  CONTROLLER_SOURCE = begin
    File.read(File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__))
      .gsub(/\r\n?/, "\n")
      .sub("import { Controller } from \"@hotwired/stimulus\"\n\n", "")
      .sub("export default class extends Controller {", "class RailsTablePreferencesController extends Controller {")
  end

  TEMPLATE = <<~HTML
    <!doctype html>
    <html>
      <body>
        <div id="source"></div>
        <table id="matching-one"></table>
        <table id="matching-two"></table>
        <table id="unrelated"></table>
        <div id="editor-only"></div>

        <script>
          (() => {
            class Controller {}
            const controllerSource = #{CONTROLLER_SOURCE.dump}
            const factory = new Function("Controller", `${controllerSource}; return RailsTablePreferencesController;`)
            const ControllerClass = factory(Controller)

            function configure(element, tableKey, name = "default") {
              const controller = new ControllerClass()
              controller.element = element
              controller.tableKeyValue = tableKey
              controller.nameValue = name
              controller.hasPresetNameTarget = false
              controller.settingsValue = { columns: [], filters: {}, sorts: [] }
              controller.preferenceUrl = (presetName) => `/preferences/${tableKey}/${presetName}`
              controller.buildDefaultSettings = () => ({ columns: [], filters: {}, sorts: [] })
              controller.mergeSettings = (_defaults, settings) => structuredClone(settings)
              controller.renderEditor = () => {}
              controller.installResizeHandles = () => {}
              controller.installTableColumnDragHandles = () => {}
              controller.installFilterControls = () => {}
              controller.installSortControls = () => {}
              controller.setStatus = () => {}
              controller.refreshPresetOptionsOnConnect = () => {}
              controller.uninstallDocumentResizeListeners = () => {}
              controller.closeFilterPanel = () => {}
              controller.apply = () => {
                element.dataset.applyCount = String(Number(element.dataset.applyCount || 0) + 1)
                element.dataset.settings = JSON.stringify(controller.settingsValue)
                element.dataset.name = controller.nameValue
              }
              controller.connect()
              element.dataset.applyCount = "0"
              return controller
            }

            try {
              const source = configure(document.getElementById("source"), "orders", "inspection")
              const matchingOne = configure(document.getElementById("matching-one"), "orders")
              const matchingTwo = configure(document.getElementById("matching-two"), "orders")
              configure(document.getElementById("unrelated"), "customers")
              configure(document.getElementById("editor-only"), "orders")

              let visible = false
              source.settingsFromEditor = () => ({
                columns: [{ key: "total", visible }],
                filters: {},
                sorts: []
              })

              source.applyFromEditor({ preventDefault() {} })

              matchingOne.disconnect()
              visible = true
              source.applyFromEditor({ preventDefault() {} })

              matchingOne.connect()
              matchingOne.installSettingsSyncListener()
              matchingOne.installSettingsSyncListener()
              visible = false
              source.applyFromEditor({ preventDefault() {} })

              document.body.dataset.sourceApplyCount = document.getElementById("source").dataset.applyCount
              document.body.dataset.matchingOneApplyCount = document.getElementById("matching-one").dataset.applyCount
              document.body.dataset.matchingTwoApplyCount = document.getElementById("matching-two").dataset.applyCount
              document.body.dataset.unrelatedApplyCount = document.getElementById("unrelated").dataset.applyCount || "0"
              document.body.dataset.editorOnlyApplyCount = document.getElementById("editor-only").dataset.applyCount || "0"
              document.body.dataset.matchingName = document.getElementById("matching-one").dataset.name
              document.body.dataset.matchingSettings = document.getElementById("matching-one").dataset.settings
              document.body.dataset.ready = "true"
            } catch (error) {
              document.body.dataset.error = `${error.name}: ${error.message}`
            }
          })()
        </script>
      </body>
    </html>
  HTML

  def index
    render html: TEMPLATE.html_safe, layout: false
  end
end

Rails.application.routes.disable_clear_and_finalize = true
Rails.application.routes.append do
  get "/rails_table_preferences_cross_root_sync", to: "rails_table_preferences_cross_root_sync#index"
end
Rails.application.reload_routes!

RSpec.describe "rails_table_preferences cross-root browser synchronization", type: :system, js: true do
  it "uses the connect/disconnect lifecycle without duplicate updates" do
    visit "/rails_table_preferences_cross_root_sync"

    expect(page).to have_css("body[data-ready='true']")
    expect(page.evaluate_script("document.body.dataset.error")).to be_nil
    expect(page.evaluate_script("document.body.dataset.sourceApplyCount")).to eq("3")
    expect(page.evaluate_script("document.body.dataset.matchingOneApplyCount")).to eq("3")
    expect(page.evaluate_script("document.body.dataset.matchingTwoApplyCount")).to eq("3")
    expect(page.evaluate_script("document.body.dataset.unrelatedApplyCount")).to eq("0")
    expect(page.evaluate_script("document.body.dataset.editorOnlyApplyCount")).to eq("0")
    expect(page.evaluate_script("document.body.dataset.matchingName")).to eq("inspection")
    expect(JSON.parse(page.evaluate_script("document.body.dataset.matchingSettings"))).to include(
      "columns" => [include("key" => "total", "visible" => false)]
    )
  end
end
