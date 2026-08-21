# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences preset async status JavaScript contract" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def build_controller_sandbox
    Dir.mktmpdir("rails-table-preferences-preset-async") do |tmpdir|
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

  def run_node_contract(script:, chdir:)
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, chdir: chdir)

    expect(status).to be_success, <<~MESSAGE
      expected preset async status contract to hold

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end

  it "keeps failed save actions in the failure state and releases busy controls" do
    build_controller_sandbox do |tmpdir|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL("#{File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")}").href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const requests = []
        const events = []
        const statusTarget = { textContent: "" }
        const actionButton = { disabled: false, dataset: {} }
        const presetNameTarget = { value: "default", disabled: false }
        const editorControl = { disabled: false }
        const elementAttributes = {}
        const editorRowsTarget = {
          querySelectorAll(selector) {
            return selector === "input, button, select, textarea" ? [editorControl] : []
          }
        }
        const element = {
          tagName: "DIV",
          querySelector() { return null },
          querySelectorAll(selector) {
            if (selector === ".rails-table-preferences-editor__actions button") return [actionButton]
            if (selector === "[data-action~='rails-table-preferences#saveFromEditor']") return [actionButton]
            if (selector === "[data-action~='rails-table-preferences#deletePreset']") return []
            return []
          },
          setAttribute(name, value) { elementAttributes[name] = value },
          removeAttribute(name) { delete elementAttributes[name] }
        }
        const draftSettings = {
          columns: [{ key: "status", visible: false }],
          filters: { status: { operator: "equals", value: "pending" } },
          sorts: []
        }

        globalThis.document = { querySelector() { return { content: "csrf-token" } } }
        globalThis.fetch = async (url, options = {}) => {
          requests.push({ url, options })
          return { ok: false, status: 503, json: async () => ({}) }
        }
        console.error = () => {}

        controller.dispatch = (name, options = {}) => events.push({ name, detail: options.detail })
        controller.collectionUrlValue = "/rails_table_preferences/preferences/orders"
        Object.defineProperty(controller, "savingStatusLabelValue", { value: "設定を保存中です..." })
        Object.defineProperty(controller, "savedStatusLabelValue", { value: "設定を保存しました。" })
        Object.defineProperty(controller, "savingFailedStatusLabelValue", { value: "設定の保存を完了できませんでした。" })
        Object.defineProperty(controller, "operationFailedStatusLabelValue", { value: "設定の操作を完了できませんでした。" })
        controller.currentPreferenceEditable = true
        controller.settingsValue = { columns: [{ key: "status", visible: true }], filters: {}, sorts: [] }
        controller.settingsFromEditor = () => draftSettings
        Object.defineProperty(controller, "element", { value: element })
        Object.defineProperty(controller, "tableElement", { value: null })
        Object.defineProperty(controller, "hasStatusTarget", { value: true })
        Object.defineProperty(controller, "statusTarget", { value: statusTarget })
        Object.defineProperty(controller, "hasEditorRowsTarget", { value: true })
        Object.defineProperty(controller, "editorRowsTarget", { value: editorRowsTarget })
        Object.defineProperty(controller, "hasPresetSelectTarget", { value: false })
        Object.defineProperty(controller, "hasPresetNameTarget", { value: true })
        Object.defineProperty(controller, "presetNameTarget", { value: presetNameTarget })
        Object.defineProperty(controller, "hasDefaultPresetTarget", { value: false })
        Object.defineProperty(controller, "hasReadOnlyHintTarget", { value: false })

        await controller.saveFromEditor({ preventDefault() {} })

        if (requests.length !== 1) throw new Error("failed save should make exactly one PATCH request")
        if (requests[0].url !== "/rails_table_preferences/preferences/orders/default") {
          throw new Error(`failed save used unexpected URL: ${requests[0].url}`)
        }
        if (requests[0].options.method !== "PATCH") throw new Error("failed save did not use PATCH")
        const requestBody = JSON.parse(requests[0].options.body)
        if (JSON.stringify(requestBody.settings) !== JSON.stringify(draftSettings)) {
          throw new Error("failed save did not send the editor draft settings")
        }
        if (controller.settingsValue !== draftSettings) {
          throw new Error("failed save rolled back or replaced the editor draft settings")
        }
        if (statusTarget.textContent !== "設定の保存を完了できませんでした。") {
          throw new Error("failed save did not expose the action-specific failure status")
        }
        if (controller.statusState !== "error") throw new Error("failed save did not leave the package controller in error state")
        if (controller.busy !== false) throw new Error("failed save did not release the busy flag")
        if (elementAttributes["aria-busy"] !== "false") throw new Error("failed save did not clear aria-busy")
        if (actionButton.disabled !== false) throw new Error("failed save did not re-enable editor action buttons")
        if (presetNameTarget.disabled !== false) throw new Error("failed save did not re-enable the preset name input")
        if (editorControl.disabled !== false) throw new Error("failed save did not re-enable generated editor controls")

        const failure = events.find((event) => event.name === "error")
        if (!failure) throw new Error("failed save did not dispatch the public error event")
        if (failure.detail.action !== "save") throw new Error("failed save error event lost the save action")
        if (failure.detail.message !== "設定の保存を完了できませんでした。") {
          throw new Error("failed save error event lost the failure status message")
        }
        if (events.some((event) => event.name === "saved")) {
          throw new Error("failed save dispatched a success event")
        }
      JS

      run_node_contract(script:, chdir: tmpdir)
    end
  end

  it "does not run preset action callbacks while busy" do
    build_controller_sandbox do |tmpdir|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL("#{File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")}").href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        let callbackStarted = false

        controller.busy = true
        const result = await controller.withBusyStatus(async () => {
          callbackStarted = true
        }, {
          busyLabel: "Saving",
          successLabel: "Saved",
          errorLabel: "Failed"
        })

        if (result !== null) throw new Error("busy guard should return null for skipped preset actions")
        if (callbackStarted) throw new Error("busy guard started another preset action callback")
        if (controller.busy !== true) throw new Error("busy guard changed the existing busy state")
      JS

      run_node_contract(script:, chdir: tmpdir)
    end
  end
end
