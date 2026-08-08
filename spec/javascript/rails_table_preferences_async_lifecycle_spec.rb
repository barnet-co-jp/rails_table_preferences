# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences async lifecycle behavior" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def build_controller_sandbox
    Dir.mktmpdir("rails-table-preferences-async-lifecycle") do |tmpdir|
      package_dir = File.join(tmpdir, "app/javascript/rails_table_preferences")
      controller_dir = File.join(tmpdir, "app/javascript/controllers")
      stimulus_dir = File.join(tmpdir, "node_modules/@hotwired/stimulus")

      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(controller_dir)
      FileUtils.mkdir_p(stimulus_dir)

      File.write(File.join(tmpdir, "package.json"), "{\n  \"type\": \"module\"\n}\n")
      File.write(
        File.join(package_dir, "controller.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js"))
          .gsub('"../controllers/rails_table_preferences_controller"', '"../controllers/rails_table_preferences_controller.js"')
      )
      FileUtils.cp(
        File.join(repo_root, "app/javascript/controllers/rails_table_preferences_controller.js"),
        File.join(controller_dir, "rails_table_preferences_controller.js")
      )
      File.write(
        File.join(stimulus_dir, "package.json"),
        "{\n  \"name\": \"@hotwired/stimulus\",\n  \"type\": \"module\",\n  \"exports\": \"./index.js\"\n}\n"
      )
      File.write(File.join(stimulus_dir, "index.js"), "export class Controller {}\n")

      yield tmpdir
    end
  end

  def run_node_check(*paths, script:)
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, *paths)

    expect(status).to be_success, <<~MESSAGE
      expected async lifecycle behavior to be stable

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end

  it "does not apply a save response that resolves after disconnect" do
    build_controller_sandbox do |tmpdir|
      base_controller_path = File.join(tmpdir, "app/javascript/controllers/rails_table_preferences_controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const busyStates = []
        const statuses = []
        let appliedPayloads = 0
        let refreshedPresets = 0
        let resolveJson

        globalThis.fetch = async () => ({
          ok: true,
          json: () => new Promise((resolve) => { resolveJson = resolve })
        })

        controller.lifecycleGeneration = 1
        controller.connected = true
        controller.busy = false
        controller.currentPreferenceEditable = true
        controller.nameValue = "default"
        controller.settingsValue = { columns: [{ key: "name", visible: true }] }
        controller.savingStatusLabelValue = "Saving"
        controller.savedStatusLabelValue = "Saved"
        controller.savingFailedStatusLabelValue = "Failed"
        Object.defineProperty(controller, "currentPresetName", { get() { return this.nameValue } })
        Object.defineProperty(controller, "jsonHeaders", { get() { return { "Content-Type": "application/json" } } })
        controller.preferenceUrl = (name) => `/preferences/${name}`
        controller.setBusyState = (busy) => { controller.busy = busy; busyStates.push(busy) }
        controller.setStatus = (message) => { statuses.push(message) }
        controller.applyPreferencePayload = () => { appliedPayloads += 1 }
        controller.refreshPresetOptionsAfterMutation = async () => { refreshedPresets += 1 }
        controller.uninstallDocumentResizeListeners = () => {}
        controller.closeFilterPanel = () => {}

        const savePromise = controller.save()
        await new Promise((resolve) => setImmediate(resolve))
        if (typeof resolveJson !== "function") throw new Error("save response did not reach JSON parsing")

        controller.disconnect()
        resolveJson({ preference: { settings: { columns: [] } } })
        await savePromise

        if (appliedPayloads !== 0) throw new Error("disconnected controller applied a stale payload")
        if (refreshedPresets !== 0) throw new Error("disconnected controller refreshed preset DOM state")
        if (JSON.stringify(busyStates) !== JSON.stringify([true])) throw new Error(`unexpected busy updates: ${JSON.stringify(busyStates)}`)
        if (statuses.includes("Saved") || statuses.includes("Failed")) throw new Error(`unexpected terminal status: ${JSON.stringify(statuses)}`)
      JS

      run_node_check(base_controller_path, script:)
    end
  end

  it "keeps a successful mutation clean and emits its event when preset refresh fails" do
    build_controller_sandbox do |tmpdir|
      package_controller_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const statuses = []
        const events = []
        let cleanCount = 0

        console.error = () => {}
        globalThis.fetch = async () => ({ ok: true, json: async () => ({ name: "default", settings: {}, editable: true }) })
        controller.lifecycleGeneration = 1
        controller.connected = true
        controller.busy = false
        controller.statusState = "idle"
        controller.currentPreferenceEditable = true
        controller.nameValue = "default"
        controller.settingsValue = { columns: [], filters: {}, sorts: [] }
        controller.presetListRefreshFailedStatusLabelValue = "Saved, but refresh failed"
        controller.operationFailedStatusLabelValue = "Operation failed"
        controller.savingStatusLabelValue = "Saving"
        controller.savedStatusLabelValue = "Saved"
        controller.savingFailedStatusLabelValue = "Failed"
        Object.defineProperty(controller, "currentPresetName", { get() { return this.nameValue } })
        Object.defineProperty(controller, "jsonHeaders", { get() { return { "Content-Type": "application/json" } } })
        controller.preferenceUrl = (name) => `/preferences/${name}`
        controller.setBusyState = (busy) => { controller.busy = busy }
        controller.setStatus = (message, state = "idle") => { controller.statusState = message ? state : "idle"; statuses.push([message, state]) }
        controller.syncResetButtonState = () => {}
        controller.markEditorClean = () => { cleanCount += 1 }
        controller.dispatchPreferenceEvent = (name, detail) => { events.push([name, detail]) }
        controller.updateDirtyStateFromEditor = () => {}
        controller.applyPreferencePayload = () => {}
        controller.refreshPresetOptions = async () => { throw new Error("refresh failed") }

        await controller.save()

        const finalStatus = statuses.at(-1)
        if (JSON.stringify(finalStatus) !== JSON.stringify(["Saved, but refresh failed", "warning"])) {
          throw new Error(`expected partial-success warning, saw ${JSON.stringify(statuses)}`)
        }
        if (cleanCount !== 1) throw new Error(`expected saved settings to become clean, saw ${cleanCount}`)
        if (JSON.stringify(events) !== JSON.stringify([["saved", { action: "save" }]])) {
          throw new Error(`expected saved lifecycle event, saw ${JSON.stringify(events)}`)
        }
        if (controller.busy) throw new Error("controller remained busy after partial success")
      JS

      run_node_check(package_controller_path, script:)
    end
  end

  it "does not let an old package action complete against a reconnected generation" do
    build_controller_sandbox do |tmpdir|
      package_controller_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const events = []
        let cleanCount = 0
        let dirtyUpdateCount = 0
        let resetSyncCount = 0
        let appliedPayloads = 0
        let resolveJson
        let resolveNewAction

        globalThis.fetch = async () => ({
          ok: true,
          json: () => new Promise((resolve) => { resolveJson = resolve })
        })
        controller.lifecycleGeneration = 1
        controller.connected = true
        controller.busy = false
        controller.statusState = "idle"
        controller.currentPreferenceEditable = true
        controller.nameValue = "default"
        controller.settingsValue = { columns: [], filters: {}, sorts: [] }
        controller.savingStatusLabelValue = "Saving"
        controller.savedStatusLabelValue = "Saved"
        controller.savingFailedStatusLabelValue = "Failed"
        Object.defineProperty(controller, "currentPresetName", { get() { return this.nameValue } })
        Object.defineProperty(controller, "jsonHeaders", { get() { return { "Content-Type": "application/json" } } })
        controller.preferenceUrl = (name) => `/preferences/${name}`
        controller.setBusyState = (busy) => { controller.busy = busy }
        controller.setStatus = (message, state = "idle") => { controller.statusState = message ? state : "idle" }
        controller.syncResetButtonState = () => { resetSyncCount += 1 }
        controller.markEditorClean = () => { cleanCount += 1 }
        controller.dispatchPreferenceEvent = (name, detail) => { events.push([name, detail]) }
        controller.updateDirtyStateFromEditor = () => { dirtyUpdateCount += 1 }
        controller.applyPreferencePayload = () => { appliedPayloads += 1 }
        controller.refreshPresetOptions = async () => {}

        const oldSave = controller.save()
        await new Promise((resolve) => setImmediate(resolve))
        if (typeof resolveJson !== "function") throw new Error("old save did not reach JSON parsing")

        controller.connected = false
        controller.lifecycleGeneration = 2
        controller.connected = true
        controller.lifecycleGeneration = 3
        controller.busy = false
        controller.statusState = "success"
        controller.currentPreferenceAction = null
        controller.currentPreferenceActionContext = null
        const newAction = controller.withPreferenceAction("load", () => new Promise((resolve) => { resolveNewAction = resolve }))

        resolveJson({ name: "default", settings: {}, editable: true })
        const result = await oldSave

        if (result !== null) throw new Error(`stale package action returned ${String(result)} instead of null`)
        if (appliedPayloads !== 0) throw new Error("stale package action applied its payload")
        if (cleanCount !== 0 || dirtyUpdateCount !== 0 || resetSyncCount !== 0 || events.length !== 0) {
          throw new Error(`stale package action touched current UI: clean=${cleanCount}, dirty=${dirtyUpdateCount}, reset=${resetSyncCount}, events=${JSON.stringify(events)}`)
        }
        if (controller.currentPreferenceAction !== "load") {
          throw new Error(`stale action restored over the current action: ${String(controller.currentPreferenceAction)}`)
        }
        resolveNewAction()
        await newAction
        if (controller.currentPreferenceAction !== null) throw new Error("current action context did not restore after completion")
      JS

      run_node_check(package_controller_path, script:)
    end
  end

  it "dispatches lifecycle settings as an immutable snapshot" do
    build_controller_sandbox do |tmpdir|
      package_controller_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        let dispatchedDetail

        controller.tableKeyValue = "users"
        controller.nameValue = "default"
        controller.settingsValue = { columns: [{ key: "name", visible: true }], filters: {}, sorts: [] }
        Object.defineProperty(controller, "currentPresetName", { get() { return this.nameValue } })
        controller.dispatch = (_name, options) => { dispatchedDetail = options.detail }

        controller.dispatchPreferenceEvent("applied", { action: "apply" })
        controller.settingsValue.columns[0].visible = false

        if (dispatchedDetail.settings === controller.settingsValue) throw new Error("event leaked the mutable settings reference")
        if (dispatchedDetail.settings.columns[0].visible !== true) throw new Error("event snapshot changed with controller settings")
      JS

      run_node_check(package_controller_path, script:)
    end
  end
end
