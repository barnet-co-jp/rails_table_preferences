# frozen_string_literal: true

require "spec_helper"

class RailsTablePreferencesSystemSmokeOrdersController < ApplicationController
  helper RailsTablePreferences::TablePreferencesHelper
  include RailsTablePreferences::Controller
  include RailsTablePreferences::TablePreferencesHelper

  DEMO_TABLE_KEY = :rails_table_preferences_system_smoke_orders

  CONTROLLER_SOURCE = begin
    File.read(File.expand_path("../../app/javascript/controllers/rails_table_preferences_controller.js", __dir__))
      .gsub(/\r\n?/, "\n")
      .sub("import { Controller } from \"@hotwired/stimulus\"\n\n", "")
      .sub("export default class extends Controller {", "class RailsTablePreferencesController extends Controller {")
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

      function deepCopy(value) {
        if (Array.isArray(value)) return value.map((item) => deepCopy(item))
        if (value && typeof value === "object") {
          return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, deepCopy(item)]))
        }
        return value
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

      function bindActions(controller) {
        controller.element.querySelectorAll("[data-action]").forEach((element) => {
          element.getAttribute("data-action").split(/\s+/).filter(Boolean).forEach((token) => {
            const parts = token.includes("->") ? token.split("->") : ["click", token]
            const eventName = parts[0]
            const actionName = parts[1]
            if (!actionName || !actionName.startsWith("rails-table-preferences#")) return
            const methodName = actionName.split("#")[1]
            if (typeof controller[methodName] !== "function") return
            element.addEventListener(eventName, (event) => controller[methodName](event))
          })
        })
      }

      function installFetchStub() {
        const preferencePayloads = {
          default: {
            name: "default",
            default: false,
            editable: true,
            scope_type: "owner",
            settings: {
              columns: [
                { key: "customer_name", visible: true, order: 10, width: 240, truncate: 24 },
                { key: "amount", visible: true, order: 20, width: 120 },
                { key: "status", visible: true, order: 30, width: 120 },
                { key: "order_no", visible: true, order: 40, width: 120 },
                { key: "delivery_date", visible: true, order: 50, width: 140 },
                { key: "confirmed", visible: true, order: 60, width: 100 },
                { key: "shipping_code", visible: true, order: 70, width: 140, overflow: "nowrap" },
                { key: "shipping_notes", visible: true, order: 80, width: 160, overflow: "wrap" },
                { key: "memo", visible: false, order: 90, width: 180, truncate: 24 }
              ],
              filters: {
                status: { operator: "eq", value: "未出荷" }
              },
              sorts: [
                { key: "amount", direction: "desc" }
              ]
            }
          },
          compact: {
            name: "compact",
            default: false,
            editable: true,
            scope_type: "owner",
            settings: {
              columns: [
                { key: "order_no", visible: true, order: 10, width: 120 },
                { key: "customer_name", visible: true, order: 20, width: 220, truncate: 18 },
                { key: "status", visible: true, order: 30, width: 110 },
                { key: "amount", visible: true, order: 40, width: 120 },
                { key: "delivery_date", visible: true, order: 50, width: 140 },
                { key: "confirmed", visible: false, order: 60, width: 100 },
                { key: "shipping_code", visible: false, order: 70, width: 140, overflow: "nowrap" },
                { key: "shipping_notes", visible: false, order: 80, width: 160, overflow: "wrap" },
                { key: "memo", visible: false, order: 90, width: 180, truncate: 24 }
              ],
              filters: {},
              sorts: [
                { key: "order_no", direction: "asc" }
              ]
            }
          },
          "共有ビュー": {
            name: "共有ビュー",
            default: false,
            editable: false,
            scope_type: "shared",
            scope_label: "shared",
            settings: {
              columns: [
                { key: "customer_name", visible: true, order: 10, width: 240, truncate: 24 },
                { key: "amount", visible: false, order: 20, width: 120 },
                { key: "status", visible: true, order: 30, width: 120 },
                { key: "order_no", visible: true, order: 40, width: 120 },
                { key: "delivery_date", visible: true, order: 50, width: 140 },
                { key: "confirmed", visible: true, order: 60, width: 100 },
                { key: "shipping_code", visible: true, order: 70, width: 140, overflow: "nowrap" },
                { key: "shipping_notes", visible: true, order: 80, width: 160, overflow: "wrap" },
                { key: "memo", visible: false, order: 90, width: 180, truncate: 24 }
              ],
              filters: {},
              sorts: []
            }
          }
        }
        const fetchOverrides = []
        const mutations = []

        function wait(delay) {
          return new Promise(function(resolve) { window.setTimeout(resolve, delay) })
        }

        function buildResponse(payload, ok, status) {
          return {
            ok: ok,
            status: status,
            json: async function() { return deepCopy(payload) }
          }
        }

        function collectionPayload() {
          return {
            preferences: Object.keys(preferencePayloads).map(function(key) {
              const payload = preferencePayloads[key]
              return {
                name: payload.name,
                default: payload.default === true,
                editable: payload.editable !== false,
                scope_type: payload.scope_type,
                scope_label: payload.scope_label,
                scope_key: payload.scope_key
              }
            })
          }
        }

        function preferencePayload(name) {
          return deepCopy(preferencePayloads[name] || preferencePayloads.default)
        }

        function consumeFetchOverride(method, kind, name) {
          for (let index = 0; index < fetchOverrides.length; index += 1) {
            const override = fetchOverrides[index]
            if (override.method !== method) continue
            if (override.kind && override.kind !== kind) continue
            if (override.name && override.name !== name) continue
            fetchOverrides.splice(index, 1)
            return override
          }
          return null
        }

        function overrideValue(override, key, fallback) {
          return override && Object.prototype.hasOwnProperty.call(override, key) ? override[key] : fallback
        }

        window.__rtpTestApi = {
          mutations,
          queueFetchOverride: function(override) {
            fetchOverrides.push({
              method: override.method,
              kind: override.kind,
              name: override.name,
              ok: override.ok,
              status: override.status,
              delay: override.delay,
              error: override.error
            })
          }
        }

        window.fetch = async function(url, options = {}) {
          const method = String(options.method || "GET").toUpperCase()
          const normalizedUrl = String(url)
          const pathTail = decodeURIComponent(normalizedUrl.split("/").pop() || "")
          const isPreferenceGet = method === "GET" && Object.prototype.hasOwnProperty.call(preferencePayloads, pathTail)
          const kind = isPreferenceGet ? "preference" : (method === "GET" ? "collection" : "mutation")
          const name = isPreferenceGet ? pathTail : null
          const override = consumeFetchOverride(method, kind, name)

          if (override && override.delay) await wait(override.delay)
          if (override && override.error) throw new Error(override.error)

          if (method === "GET") {
            if (isPreferenceGet) {
              return buildResponse(
                preferencePayload(name),
                overrideValue(override, "ok", true),
                overrideValue(override, "status", 200)
              )
            }
            return buildResponse(
              collectionPayload(),
              overrideValue(override, "ok", true),
              overrideValue(override, "status", 200)
            )
          }

          const body = options.body ? JSON.parse(options.body) : {}
          mutations.push({
            method,
            url: normalizedUrl,
            name: body.name,
            settings: deepCopy(body.settings)
          })

          return buildResponse(
            { name: body.name || "default", default: body.default === true, editable: true, settings: deepCopy(body.settings || window.__rtpController.settingsValue) },
            overrideValue(override, "ok", true),
            overrideValue(override, "status", 200)
          )
        }
      }

      function smokeRoot() {
        return document.getElementById("rtp-smoke-root") ||
          document.querySelector("[data-rtp-smoke-root]") ||
          document.querySelector('[data-controller~="rails-table-preferences"]') ||
          Array.from(document.querySelectorAll('[data-controller~="rails-table-preferences"]')).find((element) => element.querySelector("table")) ||
          null
      }

      function markSmokeStage(stage) {
        document.body.dataset.rtpSmokeStage = stage
      }

      function mountController() {
        if (window.__rtpController) {
          document.body.dataset.rtpSmokeReady = "true"
          markSmokeStage("ready-existing")
          return
        }

        document.body.dataset.rtpSmokeReady = "false"
        document.body.dataset.rtpSmokeError = ""
        markSmokeStage("mount-start")

        const root = smokeRoot()
        if (!root) {
          document.body.dataset.rtpSmokeError = "root-not-found"
          markSmokeStage("root-not-found")
          return
        }

        try {
          installFetchStub()
          markSmokeStage("build-controller")

          const factory = new Function("Controller", `${controllerSource}; return RailsTablePreferencesController;`)
          const RailsTablePreferencesController = factory(Controller)
          const controller = new RailsTablePreferencesController()
          controller.element = root
          controller.identifier = "rails-table-preferences"
          controller.dispatch = function() {}

          markSmokeStage("bind-accessors")
          installTargetAccessors(controller, RailsTablePreferencesController)
          installValueAccessors(controller, RailsTablePreferencesController)
          bindActions(controller)

          const originalApplyFromEditor = controller.applyFromEditor.bind(controller)
          controller.applyFromEditor = function(event) {
            const result = originalApplyFromEditor(event)
            document.body.dataset.rtpLastAction = "apply"
            return result
          }

          markSmokeStage("connect")
          controller.connect()
          window.__rtpController = controller
          document.body.dataset.rtpSmokeReady = "true"
          markSmokeStage("ready")
        } catch (error) {
          markSmokeStage("error")
          document.body.dataset.rtpSmokeError = `${error?.name || "Error"}: ${error?.message || String(error)}`
        }
      }

      window.__rtpMountController = mountController
      mountController()
    })();
  JS

  TEMPLATE = <<~ERB
    <% smoke_root_options = { data: @smoke_data_attributes, class: "rails-table-preferences-editor" } %>

    <h1>Rails Table Preferences Demo Smoke</h1>

    <p>
      This screen mirrors the lightweight demo surface closely enough to keep one browser smoke flow under automated coverage.
    </p>

    <div id="rtp-smoke-root"
         data-rtp-smoke-root="true"
         <%= tag.attributes(smoke_root_options) %>>
      <div class="rails-table-preferences-editor__title">デモ受注一覧の表示設定</div>

      <div class="rails-table-preferences-editor__preset">
        <label for="rtp-smoke-preset-select">保存済み設定</label>
        <select id="rtp-smoke-preset-select"
                aria-describedby="rtp-smoke-preset-select-hint"
                data-rails-table-preferences-target="presetSelect"
                data-action="rails-table-preferences#selectPreset">
          <option value="default">default</option>
        </select>

        <label for="rtp-smoke-preset-name">設定名</label>
        <input type="text"
               id="rtp-smoke-preset-name"
               value="default"
               aria-describedby="rtp-smoke-preset-name-hint"
               data-rails-table-preferences-target="presetName">

        <label class="rails-table-preferences-editor__default-preset">
          <input type="checkbox"
                 data-rails-table-preferences-target="defaultPreset">
          標準設定にする
        </label>
      </div>

      <p id="rtp-smoke-preset-select-hint" class="rails-table-preferences-editor__hint">読み込む保存済み設定を選びます。</p>
      <p id="rtp-smoke-preset-name-hint" class="rails-table-preferences-editor__hint">保存または別名保存で使う設定名を入力します。</p>

      <p class="rails-table-preferences-editor__hint"
         data-rails-table-preferences-target="readOnlyHint"
         hidden></p>

      <div data-rails-table-preferences-target="editorRows" class="rails-table-preferences-editor__rows"></div>
      <div class="rails-table-preferences-editor__status"
           data-rails-table-preferences-target="status"
           role="status"
           aria-live="polite"
           aria-atomic="true"
           aria-label="保存状態"></div>

      <div class="rails-table-preferences-editor__actions">
        <button type="button" data-action="rails-table-preferences#applyFromEditor">適用</button>
        <button type="button" data-action="rails-table-preferences#saveFromEditor">保存</button>
        <button type="button" data-action="rails-table-preferences#createPresetFromEditor">別名で保存</button>
        <button type="button"
                data-action="rails-table-preferences#deletePreset"
                title="この保存済み設定を削除します。よろしいですか？"
                aria-label="削除: この保存済み設定を削除します。よろしいですか？">削除</button>
        <button type="button" data-action="rails-table-preferences#resetEditor">リセット</button>
      </div>

      <section class="rails-table-preferences-demo__export-preview">
        <h2>Export payload preview</h2>

        <p>
          This preview shows the ordered headers and column keys that the current
          saved table settings would pass into the export helper.
        </p>

        <p id="rtp-export-headers">
          <strong>Headers:</strong>
          <%= @export_payload_preview.fetch("headers", []).join(" / ") %>
        </p>

        <p id="rtp-export-column-keys">
          <strong>Column keys:</strong>
          <code><%= @export_payload_preview.fetch("column_keys", []).join(", ") %></code>
        </p>
      </section>

      <%= form_with url: request.path, method: :get do %>
        <%= text_field_tag :search_word, params[:search_word], placeholder: "得意先名" %>

        <%= table_preferences_hidden_fields(
          settings: @table_preference_settings,
          columns: @table_columns
        ) %>

        <%= submit_tag "検索" %>
      <% end %>

      <table class="table">
        <thead>
          <tr>
            <th data-rails-table-preferences-column-key="order_no">受注番号</th>
            <th data-rails-table-preferences-column-key="customer_name">得意先名</th>
            <th data-rails-table-preferences-column-key="delivery_date">納品日</th>
            <th data-rails-table-preferences-column-key="status">状態</th>
            <th data-rails-table-preferences-column-key="confirmed">確認済</th>
            <th data-rails-table-preferences-column-key="amount">金額</th>
            <th data-rails-table-preferences-column-key="shipping_code">配送コード</th>
            <th data-rails-table-preferences-column-key="shipping_notes">配送メモ</th>
            <th data-rails-table-preferences-column-key="memo">備考</th>
          </tr>
        </thead>
        <tbody>
          <% @orders.each do |order| %>
            <tr>
              <td data-rails-table-preferences-column-key="order_no"><%= order[:order_no] %></td>
              <td data-rails-table-preferences-column-key="customer_name"><%= order[:customer_name] %></td>
              <td data-rails-table-preferences-column-key="delivery_date"><%= l(order[:delivery_date]) %></td>
              <td data-rails-table-preferences-column-key="status"><%= order[:status] %></td>
              <td data-rails-table-preferences-column-key="confirmed"><%= order[:confirmed] ? "はい" : "いいえ" %></td>
              <td data-rails-table-preferences-column-key="amount"><%= number_with_delimiter(order[:amount]) %></td>
              <td data-rails-table-preferences-column-key="shipping_code"><%= order[:shipping_code] %></td>
              <td data-rails-table-preferences-column-key="shipping_notes"><%= order[:shipping_notes] %></td>
              <td data-rails-table-preferences-column-key="memo"><%= order[:memo] %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <div aria-hidden="true" style="height: 1600px;"></div>
  ERB

  def index
    @table_columns = table_columns
    @table_preference_settings = rails_table_preference_settings(table_key: DEMO_TABLE_KEY)
    @export_payload_preview = RailsTablePreferences::ExportPayload.call(
      settings: @table_preference_settings,
      columns: @table_columns
    )
    @smoke_data_attributes = table_preferences_data_attributes(
      table_key: DEMO_TABLE_KEY,
      settings: @table_preference_settings,
      columns: @table_columns
    )
    preference_params = rails_table_preference_params(table_key: DEMO_TABLE_KEY, columns: @table_columns)
    @orders = apply_demo_params(demo_orders, params.to_unsafe_h.merge(preference_params))
    render inline: TEMPLATE, type: :erb
  end

  def rails_table_preference_settings(table_key:, name: nil, owner: nil, scope_context: nil, fallback: {})
    super(
      table_key: table_key,
      name: name,
      owner: owner,
      scope_context: scope_context,
      fallback: fallback.presence || owner_demo_preset_settings
    )
  end

  private

  def table_columns
    [
      table_preferences_column(:order_no, label: "受注番号", default_width: 120, sortable: true),
      table_preferences_column(
        :customer_name,
        label: "得意先名",
        default_width: 240,
        default_truncate: 24,
        filter: { type: :text, param: :search_word },
        sortable: true
      ),
      table_preferences_column(
        :delivery_date,
        label: "納品日",
        default_width: 140,
        filter: { type: :date, from_param: :from_delivery_date, to_param: :to_delivery_date },
        sortable: true
      ),
      table_preferences_column(
        :status,
        label: "状態",
        default_width: 120,
        filter: { type: :select, param: :status, options: ["未出荷", "出荷済", "保留"] },
        sortable: true
      ),
      table_preferences_column(
        :confirmed,
        label: "確認済",
        default_width: 100,
        filter: { type: :boolean, param: :confirmed }
      ),
      table_preferences_column(:amount, label: "金額", default_width: 120, sortable: true),
      table_preferences_column(:shipping_code, label: "配送コード", default_width: 140, overflow: "nowrap"),
      table_preferences_column(:shipping_notes, label: "配送メモ", default_width: 160, overflow: "wrap"),
      table_preferences_column(:memo, label: "備考", default_width: 180, default_truncate: 24),
      table_preferences_column(:internal_cost, label: "内部原価", ignored: true)
    ]
  end

  def demo_orders
    [
      {
        order_no: "A001",
        customer_name: "山田商事 東京本店",
        delivery_date: Date.current,
        status: "未出荷",
        confirmed: true,
        amount: 12_000,
        shipping_code: "TOKYO-AM-PRIMARY-001",
        shipping_notes: "午前指定のため、到着後すぐに検品できるよう納品書を最上段へ入れてください。",
        memo: "初回出荷のため伝票控えを同梱してください。"
      },
      {
        order_no: "A002",
        customer_name: "田中物流 関西センター",
        delivery_date: Date.current + 1.day,
        status: "出荷済",
        confirmed: false,
        amount: 34_000,
        shipping_code: "KANSAI-PALLET-RETURN-220",
        shipping_notes: "午後着。パレット回収あり。荷下ろし口の案内を事前連絡すると現場が止まりにくい案件です。",
        memo: "列幅変更と省略表示の確認に使えます。"
      },
      {
        order_no: "A003",
        customer_name: "佐藤食品 冷凍倉庫",
        delivery_date: Date.current + 2.days,
        status: "保留",
        confirmed: true,
        amount: 56_000,
        shipping_code: "FREEZER-CHECK-WAITING-305",
        shipping_notes: "温度帯確認待ち。確認が取れしだい、冷凍便と常温便のどちらで出すかを切り替える予定です。",
        memo: "ステータス絞り込みと並び替えの確認向けです。"
      },
      {
        order_no: "A004",
        customer_name: "東京医療機器",
        delivery_date: Date.current + 3.days,
        status: "未出荷",
        confirmed: true,
        amount: 89_000,
        shipping_code: "TOKYO-MEDICAL-RUSH-410",
        shipping_notes: "東京都内向けの追加便です。午後の短い時間帯しか受け取りできないため、到着前の電話連絡が必要です。",
        memo: "得意先名で「東京」を検索したときのヒット行です。"
      },
      {
        order_no: "A005",
        customer_name: "東京製菓",
        delivery_date: Date.current + 5.days,
        status: "出荷済",
        confirmed: false,
        amount: 21_500,
        shipping_code: "TOKYO-SWEETS-WEEKLY-088",
        shipping_notes: "定期便。納品口は狭いですが荷受け自体は短時間で終わるため、積み下ろし手順のメモが折り返して表示される列です。",
        memo: "備考をやや短めにして、同じ検索語でも表示差が分かるようにしています。"
      },
      {
        order_no: "A006",
        customer_name: "北星化学",
        delivery_date: Date.current + 7.days,
        status: "保留",
        confirmed: true,
        amount: 104_000,
        shipping_code: "HOKUSEI-MONTH-END-HOLD-512",
        shipping_notes: "月末締め案件。shared preset と owner preset の切り替え時に列差分を見比べやすいよう、もっとも長い配送メモを入れています。",
        memo: "shared preset と owner preset の切り替え時に列差分を見比べやすいサンプルです。"
      }
    ]
  end

  def apply_demo_params(orders, merged_params)
    filtered = orders
    search_word = merged_params["search_word"].presence || merged_params[:search_word]
    status = merged_params["status"].presence || merged_params[:status]
    from_delivery_date = parse_date(merged_params["from_delivery_date"].presence || merged_params[:from_delivery_date])
    to_delivery_date = parse_date(merged_params["to_delivery_date"].presence || merged_params[:to_delivery_date])

    filtered = filtered.select { |order| order[:customer_name].include?(search_word) } if search_word.present?
    filtered = filtered.select { |order| order[:status] == status } if status.present?
    filtered = filtered.select { |order| order[:delivery_date] >= from_delivery_date } if from_delivery_date
    filtered = filtered.select { |order| order[:delivery_date] <= to_delivery_date } if to_delivery_date

    sort_orders(filtered, merged_params["sort"].presence || merged_params[:sort])
  end

  def sort_orders(orders, sort)
    key = sort.to_s.delete_prefix("-").presence
    return orders unless key

    sorted = orders.sort_by { |order| order[key.to_sym] || "" }
    sort.to_s.start_with?("-") ? sorted.reverse : sorted
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def owner_demo_preset_settings
    {
      "columns" => [
        { "key" => "customer_name", "visible" => true, "order" => 10, "width" => 240, "truncate" => 24 },
        { "key" => "amount", "visible" => true, "order" => 20, "width" => 120 },
        { "key" => "status", "visible" => true, "order" => 30, "width" => 120 },
        { "key" => "order_no", "visible" => true, "order" => 40, "width" => 120 },
        { "key" => "delivery_date", "visible" => true, "order" => 50, "width" => 140 },
        { "key" => "confirmed", "visible" => true, "order" => 60, "width" => 100 },
        { "key" => "shipping_code", "visible" => true, "order" => 70, "width" => 140, "overflow" => "nowrap" },
        { "key" => "shipping_notes", "visible" => true, "order" => 80, "width" => 160, "overflow" => "wrap" },
        { "key" => "memo", "visible" => false, "order" => 90, "width" => 180, "truncate" => 24 }
      ],
      "filters" => {
        "status" => { "operator" => "eq", "value" => "未出荷" }
      },
      "sorts" => [
        { "key" => "amount", "direction" => "desc" }
      ]
    }
  end
end

Rails.application.routes.disable_clear_and_finalize = true
Rails.application.routes.append do
  get "/rails_table_preferences_system_smoke/orders", to: "rails_table_preferences_system_smoke_orders#index"
end
Rails.application.reload_routes!

RSpec.describe "rails_table_preferences demo browser smoke", type: :system, js: true do
  def visit_demo_smoke
    visit "/rails_table_preferences_system_smoke/orders"

    expect(page).to have_css("#rtp-smoke-root[data-rtp-smoke-root='true']", visible: false)

    page.execute_script(<<~JS, RailsTablePreferencesSystemSmokeOrdersController::BROWSER_SMOKE_SCRIPT)
      document.body.dataset.rtpHarnessWrapper = "started"
      new Function(arguments[0])()
      document.body.dataset.rtpHarnessWrapper = "completed"
    JS

    expect(page).to have_css("body[data-rtp-harness-wrapper='completed']", visible: false)
  end

  def ensure_smoke_controller_mounted
    smoke_ready = page.evaluate_script("document.body.dataset.rtpSmokeReady || ''")
    smoke_error = page.evaluate_script("document.body.dataset.rtpSmokeError || ''")
    smoke_stage = page.evaluate_script("document.body.dataset.rtpSmokeStage || ''")
    mount_present = page.evaluate_script("typeof window.__rtpMountController")
    controller_present = page.evaluate_script("typeof window.__rtpController")
    wrapper_state = page.evaluate_script("document.body.dataset.rtpHarnessWrapper || ''")

    expect(smoke_ready).to eq("true"), "smoke mount failed at stage=#{smoke_stage.inspect} error=#{smoke_error.inspect} mount=#{mount_present.inspect} controller=#{controller_present.inspect} wrapper=#{wrapper_state.inspect}"
    expect(smoke_error).to eq("")
    expect(smoke_stage).to match(/ready/)
  end

  def filter_button_selector(key)
    %[button[data-rails-table-preferences-filter-button][data-rails-table-preferences-column-key='#{key}']]
  end

  def filter_panel_selector(key)
    %[.rails-table-preferences-filter-panel[data-rails-table-preferences-column-key='#{key}']]
  end

  def editor_row_selector(key)
    %[.rails-table-preferences-editor__row[data-rails-table-preferences-column-key='#{key}']]
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

  def open_filter_panel_for(key)
    find(filter_button_selector(key), visible: :all).click
    expect(page.has_css?(filter_panel_selector(key))).to eq(true)
  end

  def current_query_state
    page.evaluate_script(<<~JS)
      (() => {
        const params = new URLSearchParams(window.location.search)
        return {
          searchWord: params.get("search_word"),
          sort: params.get("sort"),
          status: params.get("status")
        }
      })()
    JS
  end

  def visible_order_numbers
    page.all("tbody tr td[data-rails-table-preferences-column-key='order_no']").map(&:text)
  end

  def control_disabled?(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const control = document.querySelector(#{selector.inspect})
        return control ? control.disabled === true : null
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

  it "renders the demo surface and hides a column through apply" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    expect(page.has_text?("Rails Table Preferences Demo Smoke")).to eq(true)
    expect(page.has_css?("th[data-rails-table-preferences-column-key='order_no']", text: "受注番号")).to eq(true)
    expect(page.has_no_css?("th[data-rails-table-preferences-column-key='internal_cost']")).to eq(true)
    expect(page.has_css?(editor_row_selector("customer_name"), visible: :all)).to eq(true)

    row = find(editor_row_selector("customer_name"), visible: :all)
    row.find("input[data-field='visible']", visible: :all).uncheck
    find("[data-action~='rails-table-preferences#applyFromEditor']", match: :first).click

    expect(page.has_selector?("body[data-rtp-last-action='apply']")).to eq(true)
    expect(page.evaluate_script("Array.from(document.querySelectorAll('th[data-rails-table-preferences-column-key=\\\"customer_name\\\"]')).every((cell) => cell.hidden)")).to eq(true)
    expect(page.evaluate_script("Array.from(document.querySelectorAll('td[data-rails-table-preferences-column-key=\\\"customer_name\\\"]')).every((cell) => cell.hidden)")).to eq(true)
    expect(page.evaluate_script("Array.from(document.querySelectorAll('th[data-rails-table-preferences-column-key=\\\"order_no\\\"]')).every((cell) => !cell.hidden)")).to eq(true)
  end

  it "explains the roles of the preset selector and preset name field" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    expect(find("#rtp-smoke-preset-select", visible: :all)["aria-describedby"]).to eq("rtp-smoke-preset-select-hint")
    expect(find("#rtp-smoke-preset-name", visible: :all)["aria-describedby"]).to eq("rtp-smoke-preset-name-hint")
    expect(page).to have_css("#rtp-smoke-preset-select-hint", text: "読み込む保存済み設定を選びます。")
    expect(page).to have_css("#rtp-smoke-preset-name-hint", text: "保存または別名保存で使う設定名を入力します。")
  end

  it "loads a shared preset as read-only and saves edits through owner fallback" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    expect(page).to have_css("#rtp-smoke-preset-select option[value='共有ビュー']", visible: :all)

    find("#rtp-smoke-preset-select option[value='共有ビュー']", visible: :all).select_option

    expect(control_disabled?("[data-rails-table-preferences-target='defaultPreset']")).to eq(true)
    expect(control_disabled?("[data-action~='rails-table-preferences#deletePreset']")).to eq(true)
    expect(find("[data-action~='rails-table-preferences#saveFromEditor']", visible: :all)["data-rails-table-preferences-non-editable-fallback"]).to eq("true")

    find("[data-action~='rails-table-preferences#saveFromEditor']", visible: :all).click

    expect(page).to have_css(".rails-table-preferences-editor__status", text: "新しい設定を保存しました。")

    mutations = page.evaluate_script("window.__rtpTestApi.mutations")
    expect(mutations.map { |mutation| mutation.fetch("method") }).to eq(["POST"])
    expect(mutations.first.fetch("url")).to end_with("/rails_table_preferences/preferences/rails_table_preferences_system_smoke_orders")
    expect(mutations.first.fetch("name")).to eq("共有ビュー")
    expect(mutations.first.fetch("settings").fetch("columns")).to include(
      hash_including("key" => "amount", "visible" => false)
    )
  end

  it "shows export payload preview without hidden columns and in saved order" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    expect(page).to have_css("#rtp-export-headers", text: "Headers: 得意先名 / 金額 / 状態 / 受注番号 / 納品日 / 確認済 / 配送コード / 配送メモ")
    expect(page).to have_css("#rtp-export-column-keys", text: "Column keys: customer_name, amount, status, order_no, delivery_date, confirmed, shipping_code, shipping_notes")
    expect(find("#rtp-export-column-keys").text).not_to include("memo")
  end

  it "round-trips saved hidden field filters and sort through the search form" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    fill_in "search_word", with: "東京"
    click_button "検索"

    query_state = current_query_state

    expect(query_state["searchWord"]).to eq("東京")
    expect(query_state["sort"]).to eq("-amount")
    expect(query_state["status"]).to eq("未出荷")
    expect(visible_order_numbers).to eq(%w[A004 A001])
    expect(page).to have_text("東京医療機器")
    expect(page).to have_no_text("東京製菓")
  end

  it "summarizes the active filter button through title and aria-label" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    open_filter_panel_for("customer_name")
    within(filter_panel_selector("customer_name")) do
      find("[data-field='value']").set("東京")
      find("[data-action='apply-filter']").click
    end

    expect(page.has_no_css?(filter_panel_selector("customer_name"))).to eq(true)
    expect(find(filter_button_selector("customer_name"), visible: :all).text).to eq("▾")
    expect(filter_button_attribute("customer_name", "aria-pressed")).to eq("true")
    expect(filter_button_attribute("customer_name", "aria-label")).to eq("絞り込み: 得意先名 (含む: 東京)")
    expect(filter_button_attribute("customer_name", "title")).to eq("絞り込み: 得意先名 (含む: 東京)")
  end

  it "closes the open filter panel on viewport resize" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    open_filter_panel_for("customer_name")
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("true")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(true)

    page.execute_script("window.dispatchEvent(new Event('resize'))")

    expect(page.has_no_css?(filter_panel_selector("customer_name"))).to eq(true)
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("false")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(false)
  end

  it "switches filter panel inputs when the operator changes" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    find("th[data-rails-table-preferences-column-key='customer_name'] [data-rails-table-preferences-filter-button]").click
    expect(page).to have_css(".rails-table-preferences-filter-panel [data-field='value']")

    within(".rails-table-preferences-filter-panel") do
      find("select[data-field='operator'] option[value='blank']", visible: :all).select_option
    end

    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='value']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='from']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='to']")

    find("th[data-rails-table-preferences-column-key='delivery_date'] [data-rails-table-preferences-filter-button]").click

    within(".rails-table-preferences-filter-panel") do
      find("select[data-field='operator'] option[value='between']", visible: :all).select_option
    end

    expect(page).to have_css(".rails-table-preferences-filter-panel [data-field='from']")
    expect(page).to have_css(".rails-table-preferences-filter-panel [data-field='to']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='value']")

    find("th[data-rails-table-preferences-column-key='status'] [data-rails-table-preferences-filter-button]").click
    expect(page).to have_css(".rails-table-preferences-filter-panel select[data-field='values'][multiple]")

    find("th[data-rails-table-preferences-column-key='confirmed'] [data-rails-table-preferences-filter-button]").click

    within(".rails-table-preferences-filter-panel") do
      find("select[data-field='operator'] option[value='true']", visible: :all).select_option
    end

    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='value']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='from']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='to']")
    expect(page).to have_no_css(".rails-table-preferences-filter-panel [data-field='values']")
  end

  it "auto-fits the representative demo column and keeps overflow modes distinct" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    initial_width = page.evaluate_script(<<~JS)
      (() => {
        const cell = document.querySelector('th[data-rails-table-preferences-column-key="shipping_notes"]')
        return Math.round(cell.getBoundingClientRect().width)
      })()
    JS

    page.execute_script(<<~JS)
      (() => {
        const handle = document.querySelector('th[data-rails-table-preferences-column-key="shipping_notes"] [data-rails-table-preferences-resize-handle]')
        handle.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))
      })()
    JS

    auto_fit_width = page.evaluate_script(<<~JS)
      (() => {
        const cell = document.querySelector('th[data-rails-table-preferences-column-key="shipping_notes"]')
        return Math.round(cell.getBoundingClientRect().width)
      })()
    JS

    expect(auto_fit_width).to be > initial_width
    expect(page.evaluate_script("document.querySelector('td[data-rails-table-preferences-column-key=\"shipping_notes\"]').dataset.railsTablePreferencesOverflow")).to eq("wrap")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('td[data-rails-table-preferences-column-key=\"shipping_notes\"]')).whiteSpace")).to eq("normal")
    expect(page.evaluate_script("document.querySelector('td[data-rails-table-preferences-column-key=\"shipping_code\"]').dataset.railsTablePreferencesOverflow")).to eq("nowrap")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('td[data-rails-table-preferences-column-key=\"shipping_code\"]')).whiteSpace")).to eq("nowrap")
    expect(page.evaluate_script("document.querySelector('td[data-rails-table-preferences-column-key=\"memo\"]').dataset.railsTablePreferencesOverflow")).to eq("ellipsis")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('td[data-rails-table-preferences-column-key=\"memo\"]')).textOverflow")).to eq("ellipsis")
  end

  it "closes the open filter panel on page scroll" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    open_filter_panel_for("customer_name")
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("true")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(true)

    page.execute_script("window.scrollTo(0, document.body.scrollHeight); document.dispatchEvent(new Event('scroll', { bubbles: true }))")

    expect(page.has_no_css?(filter_panel_selector("customer_name"))).to eq(true)
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("false")
    expect(filter_button_has_attribute?("customer_name", "aria-controls")).to eq(false)
  end

  it "closes the filter panel with Escape and returns focus to the trigger button" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    open_filter_panel_for("customer_name")

    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("true")
    expect(page.evaluate_script("document.activeElement?.dataset.field || ''")).to eq("operator")

    find("#{filter_panel_selector("customer_name")} [data-field='operator']", visible: :all).send_keys(:escape)

    expect(page.has_no_css?(filter_panel_selector("customer_name"))).to eq(true)
    expect(filter_button_attribute("customer_name", "aria-expanded")).to eq("false")
    expect(active_element_matches?(filter_button_selector("customer_name"))).to eq(true)
  end

  it "recovers disabled controls and status text after a preset load failure" do
    visit_demo_smoke
    ensure_smoke_controller_mounted

    expect(page).to have_css("#rtp-smoke-preset-select option[value='compact']", visible: :all)

    page.execute_script(<<~JS)
      window.__rtpTestApi.queueFetchOverride({
        method: "GET",
        kind: "preference",
        name: "compact",
        ok: false,
        status: 500,
        delay: 200
      })
    JS

    find("#rtp-smoke-preset-select option[value='compact']", visible: :all).select_option

    expect(page).to have_css("#rtp-smoke-root[aria-busy='true']", visible: false)
    expect(page).to have_css(".rails-table-preferences-editor__status", text: "設定を読み込み中です...")
    expect(control_disabled?("#rtp-smoke-preset-select")).to eq(true)
    expect(control_disabled?("#rtp-smoke-preset-name")).to eq(true)
    expect(control_disabled?("[data-rails-table-preferences-target='defaultPreset']")).to eq(true)
    expect(control_disabled?("[data-action~='rails-table-preferences#saveFromEditor']")).to eq(true)

    expect(page).to have_css(".rails-table-preferences-editor__status", text: "設定の読み込みを完了できませんでした。")
    expect(page).to have_css("#rtp-smoke-root[aria-busy='false']", visible: false)
    expect(control_disabled?("#rtp-smoke-preset-select")).to eq(false)
    expect(control_disabled?("#rtp-smoke-preset-name")).to eq(false)
    expect(control_disabled?("[data-rails-table-preferences-target='defaultPreset']")).to eq(false)
    expect(control_disabled?("[data-action~='rails-table-preferences#saveFromEditor']")).to eq(false)
    expect(find("#rtp-smoke-preset-select", visible: :all).value).to eq("compact")
  end
end