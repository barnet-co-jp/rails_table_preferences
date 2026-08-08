# frozen_string_literal: true

require "fileutils"
require "open3"
require "spec_helper"
require "tmpdir"

RSpec.describe "rails_table_preferences interaction hardening behavior" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def build_base_controller_sandbox
    Dir.mktmpdir("rails-table-preferences-interaction-hardening") do |tmpdir|
      controller_dir = File.join(tmpdir, "app/javascript/controllers")
      package_dir = File.join(tmpdir, "app/javascript/rails_table_preferences")
      stimulus_dir = File.join(tmpdir, "node_modules/@hotwired/stimulus")
      FileUtils.mkdir_p(controller_dir)
      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(stimulus_dir)

      File.write(File.join(tmpdir, "package.json"), "{\n  \"type\": \"module\"\n}\n")
      FileUtils.cp(
        File.join(repo_root, "app/javascript/controllers/rails_table_preferences_controller.js"),
        File.join(controller_dir, "rails_table_preferences_controller.js")
      )
      File.write(
        File.join(package_dir, "controller.js"),
        File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js"))
          .gsub('"../controllers/rails_table_preferences_controller"', '"../controllers/rails_table_preferences_controller.js"')
      )
      File.write(
        File.join(stimulus_dir, "package.json"),
        "{\n  \"name\": \"@hotwired/stimulus\",\n  \"type\": \"module\",\n  \"exports\": \"./index.js\"\n}\n"
      )
      File.write(File.join(stimulus_dir, "index.js"), "export class Controller {}\n")

      yield(
        File.join(controller_dir, "rails_table_preferences_controller.js"),
        File.join(package_dir, "controller.js")
      )
    end
  end

  def run_node_check(*paths, script:)
    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", script, *paths)

    expect(status).to be_success, <<~MESSAGE
      expected interaction hardening behavior to be stable

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end

  it "keeps encoded filter panel ids distinct for adversarial column keys" do
    build_base_controller_sandbox do |controller_path, package_controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: BaseControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const { default: PackageControllerClass } = await import(pathToFileURL(process.argv[2]).href)
        const controller = new BaseControllerClass()
        controller.tableKeyValue = "orders/index"
        controller.filterPanelInstanceId = 7

        const slashId = controller.filterPanelId("a/b")
        const literalEscapeId = controller.filterPanelId("a_2Fb")
        if (slashId === literalEscapeId) throw new Error(`filter panel ids collided: ${slashId}`)
        if (!slashId.includes("14_orders%2Findex") || !slashId.endsWith("5_a%2Fb")) {
          throw new Error(`filter panel id did not preserve self-delimiting URI encoding: ${slashId}`)
        }

        const firstPackageController = new PackageControllerClass()
        firstPackageController.editorIdPrefixValue = "a-b"
        const secondPackageController = new PackageControllerClass()
        secondPackageController.editorIdPrefixValue = "a"
        const firstBoundaryId = firstPackageController.filterPanelId("c")
        const secondBoundaryId = secondPackageController.filterPanelId("b-c")
        if (firstBoundaryId === secondBoundaryId) {
          throw new Error(`filter panel segment boundaries collided: ${firstBoundaryId}`)
        }
      JS

      run_node_check(controller_path, package_controller_path, script:)
    end
  end

  it "exposes aria-sort only on the primary sort and describes every priority" do
    build_base_controller_sandbox do |controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: ControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const buildCell = (key) => {
          const indicator = { textContent: "" }
          return {
            title: "",
            dataset: {
              railsTablePreferencesColumnKey: key,
              railsTablePreferencesSortInstalled: "true"
            },
            attributes: {},
            indicator,
            classList: { toggle() {} },
            querySelector() { return indicator },
            setAttribute(name, value) { this.attributes[name] = value },
            removeAttribute(name) { delete this.attributes[name] }
          }
        }

        const primary = buildCell("delivery_date")
        const secondary = buildCell("customer_code")
        secondary.dataset.railsTablePreferencesHostAriaDescription = "Business context"
        const controller = new ControllerClass()
        controller.settingsValue = {
          sorts: [
            { key: "delivery_date", direction: "asc" },
            { key: "customer_code", direction: "desc" }
          ]
        }
        Object.defineProperty(controller, "headerCells", { value: [primary, secondary] })
        controller.sortAscLabelValue = "Sort ascending"
        controller.sortDescLabelValue = "Sort descending"
        controller.sortClearLabelValue = "Clear sort"
        controller.sortPriorityLabelValue = "Sort priority"

        controller.syncSortStates()

        if (primary.attributes["aria-sort"] !== "ascending") throw new Error("primary aria-sort is missing")
        if (Object.hasOwn(secondary.attributes, "aria-sort")) throw new Error("secondary header exposed aria-sort")
        if (primary.attributes["aria-description"] !== "Sort priority: 1") throw new Error("primary priority is missing")
        if (secondary.attributes["aria-description"] !== "Business context; Sort priority: 2") throw new Error("secondary priority or host description is missing")
        if (primary.indicator.textContent !== "▲" || secondary.indicator.textContent !== "▼") {
          throw new Error("multi-sort indicators are incomplete")
        }

        controller.settingsValue = { sorts: [{ key: "delivery_date", direction: "asc" }] }
        controller.syncSortStates()
        if (secondary.attributes["aria-description"] !== "Business context") {
          throw new Error("host aria-description was not restored after clearing the secondary sort")
        }
      JS

      run_node_check(controller_path, script:)
    end
  end

  it "adds a secondary sort only for Shift-modified activation" do
    build_base_controller_sandbox do |controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: ControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const controller = new ControllerClass()
        const cell = { dataset: { railsTablePreferencesColumnKey: "customer_code" } }
        const event = {
          shiftKey: true,
          target: { closest() { return null } },
          preventDefault() {}
        }
        controller.busy = false
        controller.settingsValue = { sorts: [{ key: "delivery_date", direction: "asc" }] }
        controller.syncSortStates = () => {}

        controller.toggleSortFromHeader(event, cell, { key: "customer_code", sortable: true })

        const expected = [
          { key: "delivery_date", direction: "asc" },
          { key: "customer_code", direction: "asc" }
        ]
        if (JSON.stringify(controller.settingsValue.sorts) !== JSON.stringify(expected)) {
          throw new Error(`unexpected additive sorts: ${JSON.stringify(controller.settingsValue.sorts)}`)
        }

        controller.settingsValue = {
          sorts: [
            { key: "delivery_date", direction: "asc" },
            { key: "customer_code", direction: "asc" },
            { key: "status", direction: "desc" }
          ]
        }
        cell.dataset.railsTablePreferencesColumnKey = "delivery_date"
        event.key = "Enter"
        controller.toggleSortFromHeader(event, cell, { key: "delivery_date", sortable: true })
        const reversed = [
          { key: "delivery_date", direction: "desc" },
          { key: "customer_code", direction: "asc" },
          { key: "status", direction: "desc" }
        ]
        if (JSON.stringify(controller.settingsValue.sorts) !== JSON.stringify(reversed)) {
          throw new Error(`Shift reversal changed priority: ${JSON.stringify(controller.settingsValue.sorts)}`)
        }

        controller.toggleSortFromHeader(event, cell, { key: "delivery_date", sortable: true })
        const cleared = [
          { key: "customer_code", direction: "asc" },
          { key: "status", direction: "desc" }
        ]
        if (JSON.stringify(controller.settingsValue.sorts) !== JSON.stringify(cleared)) {
          throw new Error(`Shift clear changed remaining priority: ${JSON.stringify(controller.settingsValue.sorts)}`)
        }
      JS

      run_node_check(controller_path, script:)
    end
  end

  it "rejects partial, unsafe, and non-positive integer values" do
    build_base_controller_sandbox do |controller_path|
      script = <<~JS
        import { pathToFileURL } from "node:url"

        const { default: ControllerClass } = await import(pathToFileURL(process.argv[1]).href)
        const controller = new ControllerClass()
        const rejected = ["1.5", "12px", "1e2", "0", "-1", "", "9007199254740992"]
        for (const value of rejected) {
          if (controller.positiveIntegerValue(value) !== null) throw new Error(`accepted invalid positive integer: ${value}`)
        }
        if (controller.positiveIntegerValue("12") !== 12 || controller.positiveIntegerValue(7) !== 7) {
          throw new Error("rejected a valid positive integer")
        }
      JS

      run_node_check(controller_path, script:)
    end
  end
end
