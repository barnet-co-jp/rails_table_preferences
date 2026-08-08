# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences cross-root settings sync" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def with_controller_sandbox
    Dir.mktmpdir("rails-table-preferences-cross-root-sync") do |tmpdir|
      controller_dir = File.join(tmpdir, "app/javascript/controllers")
      package_dir = File.join(tmpdir, "app/javascript/rails_table_preferences")
      stimulus_dir = File.join(tmpdir, "node_modules/@hotwired/stimulus")
      FileUtils.mkdir_p(controller_dir)
      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(stimulus_dir)

      File.write(File.join(tmpdir, "package.json"), "{\n  \"type\": \"module\"\n}\n")
      base_controller_path = File.join(controller_dir, "rails_table_preferences_controller.js")
      package_controller_path = File.join(package_dir, "controller.js")
      FileUtils.cp(
        File.join(repo_root, "app/javascript/controllers/rails_table_preferences_controller.js"),
        base_controller_path
      )
      File.write(
        package_controller_path,
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js"))
          .sub("../controllers/rails_table_preferences_controller\"", "../controllers/rails_table_preferences_controller.js\"")
      )
      File.write(
        File.join(stimulus_dir, "package.json"),
        "{\n  \"name\": \"@hotwired/stimulus\",\n  \"type\": \"module\",\n  \"exports\": \"./index.js\"\n}\n"
      )
      File.write(File.join(stimulus_dir, "index.js"), "export class Controller {}\n")

      yield base_controller_path, package_controller_path
    end
  end

  it "updates only connected table roots with the same table key" do
    with_controller_sandbox do |controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: ControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const listeners = new Map()
        globalThis.document = {
          addEventListener(name, listener) {
            const current = listeners.get(name) || new Set()
            current.add(listener)
            listeners.set(name, current)
          },
          removeEventListener(name, listener) {
            listeners.get(name)?.delete(listener)
          },
          emit(event) {
            for (const listener of listeners.get(event.type) || []) listener(event)
          }
        }
        globalThis.CustomEvent = class {
          constructor(type, options = {}) {
            this.type = type
            this.detail = options.detail
            this.bubbles = options.bubbles === true
            this.target = null
          }
        }

        const buildElement = (tagName, nestedTable = null) => ({
          tagName,
          querySelector(selector) { return selector === "table" ? nestedTable : null },
          dispatchEvent(event) {
            event.target = this
            document.emit(event)
            return true
          }
        })
        const configure = (controller, { tableKey, element, name = "default" }) => {
          controller.connected = true
          controller.tableKeyValue = tableKey
          controller.nameValue = name
          controller.element = element
          controller.defaultSettings = { columns: [], filters: {}, sorts: [] }
          controller.settingsValue = controller.defaultSettings
          controller.hasPresetNameTarget = false
          controller.preferenceUrl = (presetName) => `/preferences/${tableKey}/${presetName}`
          controller.mergeSettings = (_defaults, settings) => structuredClone(settings)
          controller.installSettingsSyncListener()
          return controller
        }

        const sourceTable = buildElement("TABLE")
        const source = configure(new ControllerClass(), {
          tableKey: "orders",
          element: buildElement("DIV", sourceTable),
          name: "inspection"
        })
        let sourceApplyCount = 0
        source.apply = () => { sourceApplyCount += 1 }
        source.settingsFromEditor = () => ({
          columns: [{ key: "total", visible: false }],
          filters: {},
          sorts: []
        })

        const receiver = configure(new ControllerClass(), {
          tableKey: "orders",
          element: buildElement("TABLE")
        })
        let receiverApplyCount = 0
        receiver.apply = () => { receiverApplyCount += 1 }

        const unrelated = configure(new ControllerClass(), {
          tableKey: "customers",
          element: buildElement("TABLE")
        })
        let unrelatedApplyCount = 0
        unrelated.apply = () => { unrelatedApplyCount += 1 }

        const editorOnly = configure(new ControllerClass(), {
          tableKey: "orders",
          element: buildElement("DIV")
        })
        let editorOnlyApplyCount = 0
        editorOnly.apply = () => { editorOnlyApplyCount += 1 }

        source.applyFromEditor({ preventDefault() {} })

        if (sourceApplyCount !== 1) throw new Error(`source applied ${sourceApplyCount} times`)
        if (receiverApplyCount !== 1) throw new Error(`matching table applied ${receiverApplyCount} times`)
        if (unrelatedApplyCount !== 0) throw new Error("different table key received settings")
        if (editorOnlyApplyCount !== 0) throw new Error("sibling editor draft was overwritten")
        if (receiver.nameValue !== "inspection") throw new Error("matching table did not follow preset name")
        if (receiver.urlValue !== "/preferences/orders/inspection") throw new Error("matching table did not follow preset URL")
        if (receiver.settingsValue.columns[0].visible !== false) throw new Error("matching table did not receive settings")

        receiver.uninstallSettingsSyncListener()
        source.settingsFromEditor = () => ({ columns: [{ key: "total", visible: true }], filters: {}, sorts: [] })
        source.applyFromEditor({ preventDefault() {} })
        if (receiverApplyCount !== 1) throw new Error("disconnected table root still received settings")
      JS

      stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, controller_path)
      expect(status).to be_success, "Node script failed:\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    end
  end

  it "synchronizes the package show-all-columns recovery action" do
    with_controller_sandbox do |_base_controller_path, package_controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: ControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const listeners = new Map()
        globalThis.document = {
          addEventListener(name, listener) {
            const current = listeners.get(name) || new Set()
            current.add(listener)
            listeners.set(name, current)
          },
          removeEventListener(name, listener) {
            listeners.get(name)?.delete(listener)
          },
          emit(event) {
            for (const listener of listeners.get(event.type) || []) listener(event)
          }
        }
        globalThis.CustomEvent = class {
          constructor(type, options = {}) {
            this.type = type
            this.detail = options.detail
            this.target = null
          }
        }

        const buildElement = (tagName) => ({
          tagName,
          querySelector() { return null },
          dispatchEvent(event) {
            event.target = this
            document.emit(event)
            return true
          }
        })
        const configure = (controller, element) => {
          controller.connected = true
          controller.tableKeyValue = "orders"
          controller.nameValue = "default"
          controller.element = element
          controller.defaultSettings = { columns: [], filters: {}, sorts: [] }
          controller.settingsValue = {
            columns: [{ key: "total", visible: false }],
            filters: { status: { operator: "eq", value: "open" } },
            sorts: [{ key: "total", direction: "desc" }]
          }
          controller.hasPresetNameTarget = false
          controller.preferenceUrl = (presetName) => `/preferences/orders/${presetName}`
          controller.mergeSettings = (_defaults, settings) => structuredClone(settings)
          controller.installSettingsSyncListener()
          return controller
        }

        const source = configure(new ControllerClass(), buildElement("DIV"))
        source.busy = false
        source.closeFilterPanel = () => {}
        source.renderEditor = () => {}
        source.apply = () => {}
        source.markEditorClean = () => {}
        source.syncResetButtonState = () => {}

        const receiver = configure(new ControllerClass(), buildElement("TABLE"))
        let receiverApplyCount = 0
        receiver.apply = () => { receiverApplyCount += 1 }

        source.showAllColumns({ preventDefault() {} })

        if (receiverApplyCount !== 1) throw new Error(`matching table applied ${receiverApplyCount} times`)
        if (receiver.settingsValue.columns[0].visible !== true) throw new Error("show-all settings were not synchronized")
        if (receiver.settingsValue.filters.status.value !== "open") throw new Error("filters were not preserved")
        if (receiver.settingsValue.sorts[0].direction !== "desc") throw new Error("sorts were not preserved")
      JS

      stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, package_controller_path)
      expect(status).to be_success, "Node script failed:\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    end
  end
end
