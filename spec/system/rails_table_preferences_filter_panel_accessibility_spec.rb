# frozen_string_literal: true

require "spec_helper"

class RailsTablePreferencesFilterPanelAccessibilityController < ApplicationController
  helper RailsTablePreferences::TablePreferencesHelper
  include RailsTablePreferences::Controller
  include RailsTablePreferences::TablePreferencesHelper

  DEMO_TABLE_KEY = :rails_table_preferences_filter_panel_accessibility

  CONTROLLER_SOURCE = begin
    base_source = File.read(File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__))
      .gsub(/\r\n?/, "\n")
      .sub("import { Controller } from \"@hotwired/stimulus\"\n\n", "")
      .sub("export default class extends Controller {", "class RailsTablePreferencesBaseController extends Controller {")

    package_source = File.read(File.expand_path("../../app/javascript/rails_table_preferences/controller.js", __dir__))
      .gsub(/\r\n?/, "\n")
      .sub("import RailsTablePreferencesBaseController from \"../controllers/rails_table_preferences_controller\"\n\n", "")
      .sub("export default class RailsTablePreferencesController extends RailsTablePreferencesBaseController {", "class RailsTablePreferencesController extends RailsTablePreferencesBaseController {")

    [base_source, package_source].join("\n\n")
  end

  BROWSER_SMOKE_SCRIPT = <<~JS
    (() => {
      const controllerSource = #{CONTROLLER_SOURCE.dump};

      class Controller {}

      function capitalize(value) {
        return value.charAt(0).toUpperCase() + value.slice(1)
      }

      function camelToKebab(value) {
        return value.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase()
      }

      function descriptorType(descriptor) {
        return descriptor && typeof descriptor === "object" && descriptor.type ? descriptor.type : descriptor
      }

      function descriptorDefault(descriptor) {
        return descriptor && typeof descriptor === "object" && Object.prototype.hasOwnProperty.call(descriptor, "default") ? descriptor.default : undefined
      }

      function parseValue(raw, descriptor) {
        const type = descriptorType(descriptor)
        if (type === Array) return raw ? JSON.parse(raw) : descriptorDefault(descriptor) || []
        if (type === Object) return raw ? JSON.parse(raw) : descriptorDefault(descriptor) || {}
        if (type === Number) return raw == null || raw === "" ? descriptorDefault(descriptor) ?? 0 : Number(raw)
        if (type === Boolean) return raw === "true"
        if (raw == null || raw === "") return descriptorDefault(descriptor) ?? ""
        return raw
      }

      function installTargetAccessors(controller, klass) {
        ;(klass.targets || []).forEach((name) => {
          const selector = `[data-rails-table-preferences-target~="${name}"]`
          Object.defineProperty(controller, `${name}Target`, { get() { return controller.element.querySelector(selector) } })
          Object.defineProperty(controller, `${name}Targets`, { get() { return Array.from(controller.element.querySelectorAll(selector)) } })
          Object.defineProperty(controller, `has${capitalize(name)}Target`, { get() { return controller.element.querySelector(selector) !== null } })
        })
      }

      function installValueAccessors(controller, klass) {
        controller.__stimulusValues = {}
        Object.entries(klass.values || {}).forEach(([name, descriptor]) => {
          const attributeName = `data-rails-table-preferences-${camelToKebab(name)}-value`
          controller.__stimulusValues[name] = parseValue(controller.element.getAttribute(attributeName), descriptor)
          Object.defineProperty(controller, `${name}Value`, {
            get() { return controller.__stimulusValues[name] },
            set(value) { controller.__stimulusValues[name] = value }
          })
          Object.defineProperty(controller, `has${capitalize(name)}Value`, {
            get() { return controller.__stimulusValues[name] !== undefined && controller.__stimulusValues[name] !== null }
          })
        })
      }

      function mountController() {
        document.body.dataset.rtpAccessibilitySmokeReady = "false"
        document.body.dataset.rtpAccessibilitySmokeError = ""

        try {
          const root = document.getElementById("rtp-accessibility-root")
          const factory = new Function("Controller", `${controllerSource}; return RailsTablePreferencesController;`)
          const RailsTablePreferencesController = factory(Controller)
          const controller = new RailsTablePreferencesController()
          controller.element = root
          controller.identifier = "rails-table-preferences"
          controller.dispatch = function() {}

          installTargetAccessors(controller, RailsTablePreferencesController)
          installValueAccessors(controller, RailsTablePreferencesController)
          controller.connect()

          window.__rtpAccessibilityController = controller
          document.body.dataset.rtpAccessibilitySmokeReady = "true"
        } catch (error) {
          document.body.dataset.rtpAccessibilitySmokeError = `${error?.name || "Error"}: ${error?.message || String(error)}`
        }
      }

      mountController()
    })();
  JS

  TEMPLATE = <<~ERB
    <% root_options = { data: @data_attributes } %>

    <div id="rtp-accessibility-root" <%= tag.attributes(root_options) %>>
      <div data-rails-table-preferences-target="editorRows" hidden></div>

      <table>
        <thead>
          <tr>
            <th data-rails-table-preferences-column-key="customer_name">得意先名</th>
            <th data-rails-table-preferences-column-key="order_no">受注番号</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td data-rails-table-preferences-column-key="customer_name">山田商事</td>
            <td data-rails-table-preferences-column-key="order_no">A001</td>
          </tr>
        </tbody>
      </table>
    </div>
  ERB

  def index
    @data_attributes = table_preferences_data_attributes(
      table_key: DEMO_TABLE_KEY,
      settings: {
        columns: [
          { key: "customer_name", visible: true, order: 10 },
          { key: "order_no", visible: true, order: 20 }
        ],
        filters: {},
        sorts: []
      },
      columns: [
        table_preferences_column(:customer_name, label: "得意先名", filter: { type: :text, param: :search_word }),
        table_preferences_column(:order_no, label: "受注番号")
      ]
    )

    render inline: TEMPLATE, type: :erb
  end
end

Rails.application.routes.disable_clear_and_finalize = true
Rails.application.routes.append do
  get "/rails_table_preferences_filter_panel_accessibility", to: "rails_table_preferences_filter_panel_accessibility#index"
end
Rails.application.reload_routes!

RSpec.describe "rails_table_preferences package filter panel accessibility", type: :system, js: true do
  def visit_accessibility_smoke
    visit "/rails_table_preferences_filter_panel_accessibility"
    page.execute_script(RailsTablePreferencesFilterPanelAccessibilityController::BROWSER_SMOKE_SCRIPT)

    smoke_ready = page.evaluate_script("document.body.dataset.rtpAccessibilitySmokeReady || ''")
    smoke_error = page.evaluate_script("document.body.dataset.rtpAccessibilitySmokeError || ''")

    expect(smoke_ready).to eq("true"), smoke_error
    expect(smoke_error).to eq("")
  end

  def filter_button_selector(key)
    %[button[data-rails-table-preferences-filter-button][data-rails-table-preferences-column-key='#{key}']]
  end

  def filter_panel_selector(key)
    %[.rails-table-preferences-filter-panel[data-rails-table-preferences-column-key='#{key}']]
  end

  def filter_button_attribute(key, attribute)
    page.evaluate_script(<<~JS)
      (() => {
        const button = document.querySelector(#{filter_button_selector(key).inspect})
        return button ? button.getAttribute(#{attribute.inspect}) : null
      })()
    JS
  end

  def filter_button_has_attribute?(key, attribute)
    page.evaluate_script(<<~JS)
      (() => {
        const button = document.querySelector(#{filter_button_selector(key).inspect})
        return button ? button.hasAttribute(#{attribute.inspect}) : false
      })()
    JS
  end

  def active_element_matches?(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector(#{selector.inspect})
        return Boolean(element && document.activeElement === element)
      })()
    JS
  end

  it "labels the open lightweight panel and clears controls when Escape closes it" do
    visit_accessibility_smoke

    find(filter_button_selector("customer_name"), visible: :all).click

    panel_state = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(#{filter_panel_selector("customer_name").inspect})
        const title = panel && panel.querySelector(".rails-table-preferences-filter-panel__title")
        return {
          panelId: panel && panel.id,
          role: panel && panel.getAttribute("role"),
          labelledBy: panel && panel.getAttribute("aria-labelledby"),
          titleId: title && title.id,
          titleText: title && title.textContent.trim(),
          activeField: document.activeElement?.dataset.field || ""
        }
      })()
    JS

    expect(panel_state["panelId"]).to eq(filter_button_attribute("customer_name", "aria-controls"))
    expect(panel_state["role"]).to eq("group")
    expect(panel_state["labelledBy"]).to eq(panel_state["titleId"])
    expect(panel_state["titleId"]).to eq("#{filter_button_attribute("customer_name", "aria-controls")}-title")
    expect(panel_state["titleText"]).to eq("得意先名")
    expect(panel_state["activeField"]).to eq("operator")
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("true")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(true)

    find("#{filter_panel_selector("customer_name")} [data-field='operator']", visible: :all).send_keys(:escape)

    expect(page.has_no_css?(filter_panel_selector("customer_name"))).to eq(true)
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("false")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(false)
    expect(active_element_matches?(filter_button_selector("customer_name"))).to eq(true)
  end
end
