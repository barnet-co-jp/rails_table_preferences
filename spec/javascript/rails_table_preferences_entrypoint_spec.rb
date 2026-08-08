# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences JavaScript entrypoints" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def build_entrypoint_sandbox
    Dir.mktmpdir("rails-table-preferences-entrypoints") do |tmpdir|
      package_dir = File.join(tmpdir, "app/javascript/rails_table_preferences")
      controller_dir = File.join(tmpdir, "app/javascript/controllers")
      stimulus_dir = File.join(tmpdir, "node_modules/@hotwired/stimulus")
      package_root = File.join(tmpdir, "node_modules/rails_table_preferences")

      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(controller_dir)
      FileUtils.mkdir_p(stimulus_dir)

      File.write(File.join(tmpdir, "package.json"), "{\n  \"type\": \"module\"\n}\n")
      File.write(
        File.join(package_dir, "index.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/index.js"))
          .gsub('"./controller"', '"./controller.js"')
      )
      File.write(
        File.join(package_dir, "controller.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js"))
          .gsub('"../controllers/rails_table_preferences_controller"', '"../controllers/rails_table_preferences_controller.js"')
      )
      File.write(
        File.join(package_dir, "preset_select_recovery.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/preset_select_recovery.js"))
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

      FileUtils.mkdir_p(package_root)
      File.write(File.join(package_root, "package.json"), File.read(File.join(repo_root, "package.json")))
      FileUtils.cp_r(File.join(tmpdir, "app"), package_root)

      yield tmpdir
    end
  end

  def run_node_entrypoint_check(*paths, script:, chdir: nil)
    options = chdir ? { chdir: chdir } : {}
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, *paths, **options)

    expect(status).to be_success, <<~MESSAGE
      expected documented JavaScript entrypoints to load successfully

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end

  it "loads the documented controller entrypoint as a module" do
    build_entrypoint_sandbox do |tmpdir|
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/preset_select_recovery.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const controllerModule = await import(controllerUrl)

        if (typeof controllerModule.default !== "function") {
          throw new Error("controller entrypoint did not export a default controller class")
        }
      JS

      run_node_entrypoint_check(controller_entrypoint_path, script:)
    end
  end

  it "loads the package root entrypoint and keeps the documented named export wired to the controller export" do
    build_entrypoint_sandbox do |tmpdir|
      index_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/index.js")
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/preset_select_recovery.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const indexUrl = pathToFileURL(process.argv[1]).href
        const controllerUrl = pathToFileURL(process.argv[2]).href

        const indexModule = await import(indexUrl)
        const controllerModule = await import(controllerUrl)

        if (indexModule.default !== controllerModule.default) {
          throw new Error("package root default export no longer matches the controller entrypoint")
        }

        if (indexModule.RailsTablePreferencesController !== controllerModule.default) {
          throw new Error("package root named export no longer matches the controller entrypoint")
        }
      JS

      run_node_entrypoint_check(index_entrypoint_path, controller_entrypoint_path, script:)
    end
  end

  it "loads documented package exports through Node package resolution" do
    build_entrypoint_sandbox do |tmpdir|
      script = <<~JS
        const indexModule = await import("rails_table_preferences")
        const controllerModule = await import("rails_table_preferences/controller")

        if (indexModule.default !== controllerModule.default) {
          throw new Error("package export map root no longer resolves to the controller entrypoint")
        }

        if (indexModule.RailsTablePreferencesController !== controllerModule.default) {
          throw new Error("package export map named export no longer resolves to the controller entrypoint")
        }
      JS

      run_node_entrypoint_check(script:, chdir: tmpdir)
    end
  end

  it "keeps package-only controller values out of the copied controller contract" do
    build_entrypoint_sandbox do |tmpdir|
      base_controller_path = File.join(tmpdir, "app/javascript/controllers/rails_table_preferences_controller.js")
      package_controller_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const baseUrl = pathToFileURL(process.argv[1]).href
        const packageUrl = pathToFileURL(process.argv[2]).href
        const { default: BaseController } = await import(baseUrl)
        const { default: PackageController } = await import(packageUrl)

        if (!(PackageController.prototype instanceof BaseController)) {
          throw new Error("package entrypoint no longer subclasses the copied controller")
        }

        if (Object.hasOwn(BaseController.values, "filterOperatorLabels")) {
          throw new Error("package-only filterOperatorLabels value leaked into the copied controller")
        }

        if (!Object.hasOwn(PackageController.values, "filterOperatorLabels")) {
          throw new Error("package entrypoint no longer exposes filterOperatorLabels as a package-only value")
        }
      JS

      run_node_entrypoint_check(base_controller_path, package_controller_path, script:)
    end
  end

  it "uses package entrypoint filter operator label overrides and falls back to bundled labels" do
    build_entrypoint_sandbox do |tmpdir|
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()

        controller.filterOperatorLabelsValue = {
          contains: "Includes",
          between: 42,
          equals: "",
          blank: null,
          present: undefined
        }

        if (controller.filterOperatorText("contains") !== "Includes") {
          throw new Error("filterOperatorLabelsValue override was not used for contains")
        }

        if (controller.filterOperatorText("between") !== "42") {
          throw new Error("filterOperatorLabelsValue override was not stringified")
        }

        if (controller.filterOperatorText("equals") !== "一致") {
          throw new Error("blank override did not fall back to the bundled equals label")
        }

        if (controller.filterOperatorText("blank") !== "空白") {
          throw new Error("null override did not fall back to the bundled blank label")
        }

        if (controller.filterOperatorText("present") !== "空白以外") {
          throw new Error("undefined override did not fall back to the bundled present label")
        }

        if (controller.filterOperatorText("starts_with") !== "で始まる") {
          throw new Error("missing override did not fall back to the bundled starts_with label")
        }
      JS

      run_node_entrypoint_check(controller_entrypoint_path, script:)
    end
  end

  it "keeps package editor search and move controls behavior stable" do
    build_entrypoint_sandbox do |tmpdir|
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const datasetKey = (name) => name.replace(/^data-/, "").replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())

        const attributeSelector = (selector) => {
          if (!selector.startsWith("[") || !selector.endsWith("]")) return null
          const body = selector.slice(1, -1)
          const separator = body.indexOf("=")
          if (separator < 0) return { name: body.trim(), expected: undefined }
          const name = body.slice(0, separator).trim()
          let expected = body.slice(separator + 1).trim()
          const quoted = (expected.startsWith('"') && expected.endsWith('"')) || (expected.startsWith("'") && expected.endsWith("'"))
          if (quoted) expected = expected.slice(1, -1)
          return { name, expected }
        }

        class FakeElement {
          constructor(tagName = "div") {
            this.tagName = tagName.toUpperCase()
            this.children = []
            this.parentNode = null
            this.dataset = {}
            this.attributes = {}
            this.className = ""
            this.hidden = false
            this.disabled = false
            this.checked = false
            this.value = ""
            this.textContent = ""
            this.type = ""
            this.title = ""
          }

          append(...nodes) { nodes.forEach((node) => this.appendChild(node)) }

          appendChild(node) {
            if (node.parentNode) node.parentNode.removeChild(node)
            node.parentNode = this
            this.children.push(node)
            return node
          }

          insertBefore(node, reference) {
            if (node.parentNode) node.parentNode.removeChild(node)
            node.parentNode = this
            const index = reference ? this.children.indexOf(reference) : -1
            if (index >= 0) this.children.splice(index, 0, node)
            else this.children.push(node)
            return node
          }

          removeChild(node) {
            const index = this.children.indexOf(node)
            if (index >= 0) this.children.splice(index, 1)
            node.parentNode = null
            return node
          }

          before(node) {
            if (!this.parentNode) return
            this.parentNode.insertBefore(node, this)
          }

          addEventListener() {}

          setAttribute(name, value) {
            const stringValue = String(value)
            this.attributes[name] = stringValue
            if (name.startsWith("data-")) this.dataset[datasetKey(name)] = stringValue
          }

          getAttribute(name) { return this.attributes[name] }

          removeAttribute(name) {
            delete this.attributes[name]
            if (name.startsWith("data-")) delete this.dataset[datasetKey(name)]
          }

          matches(selector) {
            if (selector.startsWith(".")) return this.className.split(/\s+/).includes(selector.slice(1))
            const attribute = attributeSelector(selector)
            if (!attribute) return false
            const { name, expected } = attribute
            const actual = name.startsWith("data-") ? this.dataset[datasetKey(name)] : this.attributes[name]
            if (expected === undefined) return actual !== undefined
            return actual === expected
          }

          querySelector(selector) { return this.querySelectorAll(selector)[0] || null }

          querySelectorAll(selector) {
            const selectors = selector.split(",").map((part) => part.trim()).filter(Boolean)
            const matchesAny = (node) => selectors.some((part) => node.matches(part))
            const results = []
            const visit = (node) => {
              node.children.forEach((child) => {
                if (matchesAny(child)) results.push(child)
                visit(child)
              })
            }
            visit(this)
            return results
          }

          closest(selector) {
            let node = this
            while (node) {
              if (node.matches(selector)) return node
              node = node.parentNode
            }
            return null
          }

          get nextSibling() {
            if (!this.parentNode) return null
            const index = this.parentNode.children.indexOf(this)
            return index >= 0 ? this.parentNode.children[index + 1] || null : null
          }
        }

        globalThis.document = { createElement: (tagName) => new FakeElement(tagName) }

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const root = document.createElement("section")
        const searchControl = document.createElement("div")
        const searchInput = document.createElement("input")
        const emptyMessage = document.createElement("p")
        const rowsTarget = document.createElement("div")

        searchControl.dataset.railsTablePreferencesEditorSearch = "true"
        searchInput.dataset.railsTablePreferencesEditorSearchInput = "true"
        emptyMessage.dataset.railsTablePreferencesEditorSearchEmpty = "true"
        searchControl.append(searchInput, emptyMessage)
        root.append(searchControl, rowsTarget)

        const buildRow = ({ key, label, searchText, visible = true, order }) => {
          const row = document.createElement("div")
          const visibleInput = document.createElement("input")
          const orderInput = document.createElement("input")
          const widthInput = document.createElement("input")
          const truncateInput = document.createElement("input")
          const upButton = document.createElement("button")
          const downButton = document.createElement("button")

          row.dataset.railsTablePreferencesColumnKey = key
          row.dataset.railsTablePreferencesEditorSearchText = searchText
          row.textContent = label
          visibleInput.setAttribute("data-field", "visible")
          visibleInput.checked = visible
          orderInput.setAttribute("data-field", "order")
          orderInput.value = String(order)
          widthInput.setAttribute("data-field", "width")
          truncateInput.setAttribute("data-field", "truncate")
          upButton.dataset.railsTablePreferencesMoveDirection = "up"
          downButton.dataset.railsTablePreferencesMoveDirection = "down"
          row.append(visibleInput, orderInput, widthInput, truncateInput, upButton, downButton)
          return { row, upButton, downButton, orderInput }
        }

        const account = buildRow({ key: "account", label: "Account", searchText: "account", order: 10 })
        const shipping = buildRow({ key: "shipping", label: "Shipping", searchText: "shipping address", order: 20 })
        const total = buildRow({ key: "total", label: "Total", searchText: "account total", order: 30 })
        rowsTarget.append(account.row, shipping.row, total.row)

        Object.defineProperty(controller, "element", { value: root })
        Object.defineProperty(controller, "hasEditorRowsTarget", { value: true })
        Object.defineProperty(controller, "editorRowsTarget", { value: rowsTarget })
        controller.settingsValue = {
          columns: [
            { key: "account", order: 10, pinned: false },
            { key: "shipping", order: 20, pinned: false },
            { key: "total", order: 30, pinned: false }
          ],
          filters: { account: { operator: "contains", value: "ACME" } },
          sorts: [{ key: "total", direction: "desc" }]
        }
        controller.busy = false

        searchInput.value = "account"
        controller.syncEditorSearchResults()

        if (account.row.hidden) throw new Error("matching first row was hidden by search")
        if (!shipping.row.hidden) throw new Error("non-matching row stayed visible during search")
        if (total.row.hidden) throw new Error("matching later row was hidden by search")
        if (rowsTarget.children.length !== 3) throw new Error("search removed filtered rows from the editor DOM")
        if (!shipping.upButton.disabled || !shipping.downButton.disabled) throw new Error("hidden row move buttons stayed enabled")
        if (!account.upButton.disabled || account.downButton.disabled) throw new Error("first visible row move button state is wrong")
        if (total.upButton.disabled || !total.downButton.disabled) throw new Error("last visible row move button state is wrong")

        const settingsWhileFiltered = controller.settingsFromEditor()
        if (settingsWhileFiltered.columns.map((column) => column.key).join(",") !== "account,shipping,total") {
          throw new Error("settingsFromEditor dropped or reordered hidden search rows before a move")
        }
        if (settingsWhileFiltered.filters.account.value !== "ACME") throw new Error("settingsFromEditor dropped existing filters")
        if (settingsWhileFiltered.sorts[0].key !== "total") throw new Error("settingsFromEditor dropped existing sorts")

        controller.moveEditorRow({ currentTarget: total.upButton, preventDefault() {} }, -1)
        if (rowsTarget.children.map((row) => row.dataset.railsTablePreferencesColumnKey).join(",") !== "total,account,shipping") {
          throw new Error("moveEditorRow did not move within the visible filtered row set")
        }
        if (shipping.row.hidden !== true) throw new Error("moveEditorRow unexpectedly changed hidden search state")
        if (total.orderInput.value !== "10" || account.orderInput.value !== "20" || shipping.orderInput.value !== "30") {
          throw new Error("moveEditorRow did not refresh numeric order inputs after moving")
        }

        const settingsAfterMove = controller.settingsFromEditor()
        if (settingsAfterMove.columns.map((column) => column.key).join(",") !== "total,account,shipping") {
          throw new Error("settingsFromEditor did not follow moved DOM order including hidden rows")
        }
        if (settingsAfterMove.columns.find((column) => column.key === "shipping")?.order !== 30) {
          throw new Error("settingsFromEditor lost the hidden row order value after moving")
        }

        controller.busy = true
        controller.syncEditorMoveButtons()
        if (!controller.editorRows.every((row) => row.querySelectorAll("[data-rails-table-preferences-move-direction]").every((button) => button.disabled))) {
          throw new Error("busy state did not disable every generated move button")
        }
      JS

      run_node_entrypoint_check(controller_entrypoint_path, script:)
    end
  end

  it "dispatches public controller lifecycle events with stable detail payloads" do
    build_entrypoint_sandbox do |tmpdir|
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const controller = new ControllerClass()
        const events = []

        controller.dispatch = (name, options = {}) => events.push({ name, detail: options.detail })
        controller.tableKeyValue = "orders"
        controller.nameValue = "default"
        controller.settingsValue = { columns: [{ key: "total", visible: true }], filters: {}, sorts: [] }
        controller.hasPresetNameTarget = false
        controller.settingsFromEditor = () => ({ columns: [{ key: "total", visible: false }], filters: { total: { operator: "gt", value: "100" } }, sorts: [] })
        controller.apply = () => {}

        controller.applyFromEditor({ preventDefault() {} })

        const applied = events.find((event) => event.name === "applied")
        if (!applied) throw new Error("applied event was not dispatched")
        if (applied.detail.tableKey !== "orders") throw new Error("applied event missing tableKey")
        if (applied.detail.name !== "default") throw new Error("applied event missing preset name")
        if (applied.detail.action !== "apply") throw new Error("applied event missing action")
        if (applied.detail.settings.filters.total.value !== "100") throw new Error("applied event missing settings snapshot")

        await controller.withPreferenceAction("save", async () => {
          controller.handleOperationError(new Error("boom"), "Save failed")
        })

        const failure = events.find((event) => event.name === "error")
        if (!failure) throw new Error("error event was not dispatched")
        if (failure.detail.action !== "save") throw new Error("error event missing stable action")
        if (failure.detail.message !== "Save failed") throw new Error("error event missing stable message")
        if (Object.prototype.hasOwnProperty.call(failure.detail, "error")) {
          throw new Error("error event leaked the Error object")
        }
      JS

      run_node_entrypoint_check(controller_entrypoint_path, script:)
    end
  end

  it "preserves host-provided sortable header titles while keeping generated sort hints for untitled headers" do
    build_entrypoint_sandbox do |tmpdir|
      controller_entrypoint_path = File.join(tmpdir, "app/javascript/rails_table_preferences/controller.js")

      script = <<~JS
        import { pathToFileURL } from "node:url"

        const controllerUrl = pathToFileURL(process.argv[1]).href
        const { default: ControllerClass } = await import(controllerUrl)
        const indicator = () => ({ textContent: "" })
        const cell = ({ key, title = "" }) => {
          const sortIndicator = indicator()
          return {
            title,
            dataset: { railsTablePreferencesColumnKey: key },
            attributes: {},
            sortIndicator,
            hasAttribute(name) { return name === "title" && title !== "" },
            classList: { add() {}, toggle() {} },
            addEventListener() {},
            appendChild(node) { this.sortIndicator = node },
            querySelector(selector) {
              return selector === "[data-rails-table-preferences-sort-indicator]" ? this.sortIndicator : null
            },
            setAttribute(name, value) { this.attributes[name] = value },
            removeAttribute(name) { delete this.attributes[name] }
          }
        }

        const hostTitleCell = cell({ key: "account", title: "Business owner help" })
        const generatedHintCell = cell({ key: "total" })
        const controller = new ControllerClass()
        controller.settingsValue = { sorts: [] }

        Object.defineProperty(controller, "headerCells", { value: [hostTitleCell, generatedHintCell] })
        controller.columnDefinitionByKey = () => ({ sortable: true })
        controller.sortAscLabelValue = "Sort ascending"
        controller.sortDescLabelValue = "Sort descending"
        controller.sortClearLabelValue = "Clear sort"

        controller.installSortControls()

        if (hostTitleCell.title !== "Business owner help") {
          throw new Error("host title was overwritten during sort control install")
        }

        if (generatedHintCell.title !== "Sort ascending") {
          throw new Error("generated sort hint was not applied to an untitled sortable header")
        }

        controller.settingsValue = { sorts: [{ key: "account", direction: "desc" }] }
        controller.syncSortStates()

        if (hostTitleCell.title !== "Business owner help") {
          throw new Error("host title was overwritten during sort state sync")
        }

        if (hostTitleCell.attributes["aria-sort"] !== "descending") {
          throw new Error("aria-sort no longer tracks the active descending sort")
        }

        if (hostTitleCell.sortIndicator.textContent !== "▼") {
          throw new Error("sort indicator no longer tracks the active descending sort")
        }
      JS

      run_node_entrypoint_check(controller_entrypoint_path, script:)
    end
  end
end
