# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences lifecycle event payloads" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def with_lifecycle_event_sandbox
    Dir.mktmpdir("rails-table-preferences-lifecycle-events") do |tmpdir|
      package_dir = File.join(tmpdir, "app/javascript/rails_table_preferences")
      controller_dir = File.join(tmpdir, "app/javascript/controllers")
      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(controller_dir)

      File.write(File.join(tmpdir, "package.json"), "{\n  \"type\": \"module\"\n}\n")
      File.write(
        File.join(package_dir, "controller.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js"))
          .gsub('"../controllers/rails_table_preferences_controller"', '"../controllers/rails_table_preferences_controller.js"')
      )
      File.write(
        File.join(controller_dir, "rails_table_preferences_controller.js"),
        <<~JS
          export default class RailsTablePreferencesBaseController {
            static values = {}
            handleOperationError() {}
          }
        JS
      )

      yield File.join(package_dir, "controller.js")
    end
  end

  def run_node_lifecycle_check(controller_entrypoint_path, script:)
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, controller_entrypoint_path)

    expect(status).to be_success, <<~MESSAGE
      expected lifecycle event payload contract to hold

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end

  it "keeps success event details limited to the documented host-app payload" do
    with_lifecycle_event_sandbox do |controller_entrypoint_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const events = []

        controller.dispatch = (name, options = {}) => events.push({ name, detail: options.detail })
        controller.tableKeyValue = "orders"
        Object.defineProperty(controller, "currentPresetName", { value: "default" })
        controller.settingsValue = { columns: [{ key: "total", visible: true }], filters: {}, sorts: [] }

        controller.dispatchPreferenceEvent("saved", { action: "save" })

        const saved = events[0]
        if (saved.name !== "saved") throw new Error("saved event name changed")
        if (saved.detail.tableKey !== "orders") throw new Error("saved event missing tableKey")
        if (saved.detail.name !== "default") throw new Error("saved event missing preset name")
        if (saved.detail.action !== "save") throw new Error("saved event missing action")
        if (saved.detail.settings.columns[0].key !== "total") throw new Error("saved event missing settings snapshot")

        for (const leakedKey of ["error", "target", "response", "event"]) {
          if (Object.prototype.hasOwnProperty.call(saved.detail, leakedKey)) {
            throw new Error(`saved event leaked ${leakedKey}`)
          }
        }
      JS

      run_node_lifecycle_check(controller_entrypoint_path, script:)
    end
  end

  it "keeps error event details display-safe and tied to the active preference action" do
    with_lifecycle_event_sandbox do |controller_entrypoint_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const events = []

        controller.dispatch = (name, options = {}) => events.push({ name, detail: options.detail })
        controller.tableKeyValue = "orders"
        Object.defineProperty(controller, "currentPresetName", { value: "default" })
        controller.settingsValue = { columns: [{ key: "total", visible: true }], filters: {}, sorts: [] }
        controller.operationFailedStatusLabelValue = "Operation failed"
        controller.currentPreferenceAction = "load"

        controller.handleOperationError(new Error("database exploded"), "Could not load preset")

        const failure = events[0]
        if (failure.name !== "error") throw new Error("error event name changed")
        if (failure.detail.tableKey !== "orders") throw new Error("error event missing tableKey")
        if (failure.detail.name !== "default") throw new Error("error event missing preset name")
        if (failure.detail.action !== "load") throw new Error("error event missing active action")
        if (failure.detail.message !== "Could not load preset") throw new Error("error event missing display-safe message")
        if (failure.detail.settings.columns[0].key !== "total") throw new Error("error event missing settings snapshot")

        for (const leakedKey of ["error", "target", "response", "event"]) {
          if (Object.prototype.hasOwnProperty.call(failure.detail, leakedKey)) {
            throw new Error(`error event leaked ${leakedKey}`)
          }
        }

        if (JSON.stringify(failure.detail).includes("database exploded")) {
          throw new Error("error event leaked the raw Error message")
        }
      JS

      run_node_lifecycle_check(controller_entrypoint_path, script:)
    end
  end
end

RSpec.describe "rails_table_preferences lifecycle event snapshot isolation" do
  let(:source) do
    File.read(File.expand_path("../../app/javascript/rails_table_preferences/controller.js", __dir__))
  end

  it "copies settings before exposing them to host listeners" do
    expect(source).to include("settings: this.settingsSnapshot(this.settingsValue)")
    expect(source).to include('if (typeof structuredClone === "function") return structuredClone(settings)')
    expect(source).to include("return JSON.parse(JSON.stringify(settings || {}))")
  end
end