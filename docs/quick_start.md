# Quick start

This guide shows the shortest path from installation to a working table preference UI.

## 1. Add the gem

For local development against this repository:

```ruby
# Gemfile
gem "rails_table_preferences", path: "../rails_table_preferences"
```

For normal usage after release, use the released gem version instead.

Then install dependencies:

```bash
bundle install
```

## 2. Run the install generator

For the default `User` owner model:

```bash
bin/rails generate rails_table_preferences:install
```

For another owner model, pass `--owner-model`. The value can be singular or plural:

```bash
bin/rails generate rails_table_preferences:install --owner-model customers
bin/rails generate rails_table_preferences:install --owner-model client
```

The generator copies:

- a migration into `db/migrate`
- `config/initializers/rails_table_preferences.rb`
- `app/javascript/controllers/rails_table_preferences_controller.js`
- `app/assets/stylesheets/rails_table_preferences.css`

### Stimulus prerequisite

The interactive editor and table behavior require a running Stimulus application. The Ruby gem and generator copy the controller, but they do not install or start Stimulus for the host app.

- Default Rails apps using `stimulus-rails`: confirm the normal controller manifest is active; the copied `_controller.js` file is then registered automatically.
- Rails apps without Stimulus: add `stimulus-rails` and run `bin/rails stimulus:install`, or install `@hotwired/stimulus` in the host frontend and start one application instance.
- Vite or another custom bundler: reuse the app's existing Stimulus application and follow the explicit registration section below.

Do not call `Application.start()` twice in the same host app.

Run the migration:

```bash
bin/rails db:migrate
```

### If the host app does not use `User` / `current_user`

When the host app uses another owner model or another current-owner method, set both in the initializer before trying the demo or bundled JSON API:

```ruby
RailsTablePreferences.configure do |config|
  config.owner_model = :customers
  config.current_user_method = :current_customer
end
```

The configured method must return a persisted record for the configured owner model. A minimal sandbox setup looks like this:

```ruby
class ApplicationController < ActionController::Base
  helper_method :current_customer

  private

  def current_customer
    Customer.first_or_create!(name: "Sandbox Customer")
  end
end
```

This matters for both the normal editor flow and the copied demo screen. `--with-demo` does not create the owner record for you; it reuses the same configured current-owner method as the rest of the gem.

### Vite / app/frontend entrypoint registration

When your app uses `app/frontend/entrypoints/application.js` instead of the default `stimulus-rails` controller manifest, register the controller explicitly from the gem entrypoint.

If the host app already starts Stimulus, reuse that existing `application` and only add this registration:

```js
import RailsTablePreferencesController from "rails_table_preferences/controller"

application.register("rails-table-preferences", RailsTablePreferencesController)
```

Only start a new Stimulus application in a minimal entrypoint that does not already start one:

```js
import { Application } from "@hotwired/stimulus"
import RailsTablePreferencesController from "rails_table_preferences/controller"

const application = Application.start()
application.register("rails-table-preferences", RailsTablePreferencesController)
```

Do not call `Application.start()` a second time from the same host app.

The `rails_table_preferences` package also exports the controller as a named export:

```js
import { RailsTablePreferencesController } from "rails_table_preferences"
```

Before those imports work, make sure the host bundler can resolve the gem's packaged `app/javascript/rails_table_preferences/*` files. Vite does not discover Ruby gem `app/javascript` paths automatically, so add an alias or equivalent resolver for `rails_table_preferences` and `rails_table_preferences/controller`.

Keep the detailed `vite.config.ts` example in [JavaScript entrypoints](javascript_entrypoints.md) as the source of truth and mirror only the minimum resolver wiring needed by your bundler.

The generator still copies `app/javascript/controllers/rails_table_preferences_controller.js` for Rails apps that rely on `stimulus-rails` default manifests. Vite apps can use the package entrypoint above to avoid depending on that copied path from `app/frontend`.

The package entrypoint is currently JavaScript-only. It does not export `rails_table_preferences/styles.css`, so keep loading the generated `app/assets/stylesheets/rails_table_preferences.css` through the host app's Rails asset path, or provide host-owned CSS if you deliberately use `--skip-stylesheets`. See [JavaScript entrypoints](javascript_entrypoints.md#stylesheet-boundary) for the current stylesheet boundary.

## 3. Mount the engine

Add the JSON API route used by the bundled editor:

```ruby
# config/routes.rb
mount RailsTablePreferences::Engine, at: "/rails_table_preferences"
```

If the host app wants the generator to add that default mount route, pass `--with-engine-route` when running the install generator:

```bash
bin/rails generate rails_table_preferences:install --with-engine-route
```

Keep the manual route path when the app reviews routes by hand or uses a custom mount path. See [Install path options](install_paths.md) for the route option boundary and [Mounted JSON API](json_api.md) for the endpoint contract.

If you change the mount path, set the same value in the initializer:

```ruby
RailsTablePreferences.configure do |config|
  config.mount_path = "/rails_table_preferences"
end
```

## 4. Define columns

If you want a convention-first path instead of hand-writing every column, start with `resource_table_for` or `tree_resource_table_for` and then continue with [Resource table adapters](resource_tables.md) for inferred columns, profile overrides, and existing search-form round-trip wiring.

```erb
<%= resource_table_for @orders %>
```

```erb
<%= tree_resource_table_for @projects, parent_id_method: :parent_project_id %>
```

When the generated resource table needs a short semantic table name, pass `caption:` on the helper call, for example `resource_table_for @orders, caption: "Orders"`. Treat that caption as the native table name, not as a replacement for the page heading, rich table summary, or business-specific instructions around the table. See [Accessibility baseline](accessibility.md#resource-table-captions) for the caption boundary and [Manual QA checklist](manual_qa.md#3-basic-rendering) for the browser check.

Use manual `table_preferences_column(...)` definitions for screens that need explicit labels, custom display blocks, or column-by-column metadata from the start. The rest of this quick start follows that manual path.

Define the table columns in the controller, helper, or another view-friendly place.

```ruby
@table_columns = [
  table_preferences_column(:order_no, label: "受注番号", default_width: 120),
  table_preferences_column(:customer_name, label: "得意先名", default_width: 240, overflow: :ellipsis),
  table_preferences_column(:delivery_date, label: "納品日", default_width: 140)
]
```

Column labels are the user-facing names shown in the preference editor. By default, Rails Table Preferences resolves them in this order:

1. `label:` passed to `table_preferences_column`
2. `i18n_key:` passed to `table_preferences_column`
3. database column comment from `model.columns_hash[key].comment`

If no label can be resolved, the column is hidden from Rails Table Preferences, the same as `ignored: true`. This avoids exposing columns that have not been marked as user-facing.

You can use database comments by passing an Active Record model class:

```ruby
@table_columns = [
  table_preferences_column(:order_no, model: Order, default_width: 120),
  table_preferences_column(:customer_name, model: Order, default_width: 240, overflow: :ellipsis),
  table_preferences_column(:delivery_date, model: Order, default_width: 140)
]
```

You can also resolve one column through a custom translation key:

```ruby
table_preferences_column(:customer_name, i18n_key: "orders.index.columns.customer_name")
```

For host apps that want Rails-style attribute locale keys, add those rules in the initializer:

```ruby
RailsTablePreferences.configure do |config|
  config.label_resolution = %i[
    label
    i18n_key
    column_comment
    activerecord_attribute_i18n
    activemodel_attribute_i18n
    attribute_i18n
  ]
end
```

Then add host app locale entries:

```yaml
ja:
  activerecord:
    attributes:
      order:
        order_no: 受注番号
        customer_name: 得意先名
        delivery_date: 納品日
```

If you prefer the old permissive fallback style, include `:humanize` or set the unresolved behavior:

```ruby
RailsTablePreferences.configure do |config|
  config.label_resolution = %i[label i18n_key column_comment humanize]
  # or:
  config.unresolved_label_behavior = :humanize
end
```

## 5. Render the editor and table

```erb
<%= table_preferences_editor(
  table_key: :orders,
  columns: @table_columns,
  title: "受注一覧の表示設定"
) %>

<%= table_preferences_table_tag(
  table_key: :orders,
  columns: @table_columns,
  class: "table"
) do %>
  <thead>
    <tr>
      <th data-rails-table-preferences-column-key="order_no">受注番号</th>
      <th data-rails-table-preferences-column-key="customer_name">得意先名</th>
      <th data-rails-table-preferences-column-key="delivery_date">納品日</th>
    </tr>
  </thead>
  <tbody>
    <% @orders.each do |order| %>
      <tr>
        <td data-rails-table-preferences-column-key="order_no"><%= order.order_no %></td>
        <td data-rails-table-preferences-column-key="customer_name"><%= order.customer_name %></td>
        <td data-rails-table-preferences-column-key="delivery_date"><%= l(order.delivery_date) if order.delivery_date %></td>
      </tr>
    <% end %>
  </tbody>
<% end %>
```

The `data-rails-table-preferences-column-key` values must match the keys passed to `table_preferences_column`.

The editor helper and table helper render separate `rails-table-preferences` controller roots. Apply, Reset, Show all columns, successful preset Save/Create/Load/Delete operations, and the packaged clear-filters-and-sorts action immediately synchronize settings to connected table roots with the same `table_key`. The table follows the active preset name while another editor root keeps its own draft state.

Use a different `table_key` for tables that should not synchronize. Synchronization is limited to connected roots in the same document; it does not cross iframes, tabs, or windows, and updates emitted while a Turbo-replaced root is disconnected are not replayed. Each Turbo response should therefore render the current server-side `settings` and preset `name`. For the exact controller-root, target-table, and synchronization rules, see [JavaScript controller notes](javascript_controller.md#cross-root-settings-synchronization). When moving a `resource_table_for` or `tree_resource_table_for` editor with `render_editor: false`, use the [Resource table editor placement checklist](render_editor_placement_manual_qa.md) to confirm the separated editor and table still receive the same `table_key`, `name`, `settings`, and `columns`.

### When one page renders multiple editors

The current bundled partial already generates unique preset select/name ids per render, so you can place more than one `table_preferences_editor` on the same page without passing an extra helper keyword.

When the host app needs stable generated control ids across repeated renders, drawers, or dialogs, pass `editor_instance_key:`. Keep it stable for the rendered editor instance; the helper combines it with `table_key` and `name` to build the internal label/select/name ids.

```erb
<%= table_preferences_editor(
  table_key: :orders,
  name: "default",
  columns: @table_columns,
  title: "画面内の設定",
  editor_instance_key: "orders-page"
) %>

<%= table_preferences_editor(
  table_key: :orders,
  name: "default",
  columns: @table_columns,
  title: "ダイアログ内の設定",
  editor_instance_key: "orders-dialog"
) %>
```

Use this rule of thumb:

- Keep `table_key` stable per logical screen or table contract.
- Leave `editor_instance_key:` omitted when per-render unique ids are enough.
- Pass a stable `editor_instance_key:` when repeated renders, drawers, or dialogs need predictable internal editor control ids.
- Treat `editor_instance_key:` as an internal id-prefix input for generated editor controls, not as a root element id/class/data/aria placement API.
- When you copy or customize the partial, preserve the label `for` to preset select/name `id` pairing and keep ids unique per rendered instance.

If the host app renders only one editor for the page, you can simply keep the default helper call.

### Applying preferences to an existing HTML table

`table_preferences_table_tag(...)` remains the default path because it emits the controller wiring and target table together. You can still use Rails Table Preferences when the host app already owns the `<table>` markup, for example after Markdown/HTML rewrite, an existing partial, or another server-rendered table builder.

Use this DOM contract:

1. Keep a stable `table_key` per logical screen/template, not per record id or request param.
2. Mount one `rails-table-preferences` controller root per managed table.
3. Put the target `<table>` inside that root, or make the root itself the `<table>`.
4. Add `data-rails-table-preferences-column-key` to each managed `th` / `td`.
5. Leave unmanaged columns without that data attribute.

Minimal table markup example:

```erb
<table class="table">
  <thead>
    <tr>
      <th data-rails-table-preferences-column-key="order_no">受注番号</th>
      <th data-rails-table-preferences-column-key="customer_name">得意先名</th>
      <th>備考</th>
    </tr>
  </thead>
  <tbody>
    <% @orders.each do |order| %>
      <tr>
        <td data-rails-table-preferences-column-key="order_no"><%= order.order_no %></td>
        <td data-rails-table-preferences-column-key="customer_name"><%= order.customer_name %></td>
        <td><%= order.note %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

In this example, `order_no` and `customer_name` remain under Rails Table Preferences control, while `備考` stays a normal host-app column.

If you bypass the bundled table helper entirely, the controller root must still receive the same core values as the normal helper output: `tableKey`, `collectionUrl`, `url`, `columns`, and `settings`. In practice it is also useful to pass the current preset `name` so the manual root stays aligned with the editor and preset select.

The example below mirrors the current bundled editor/controller contract closely enough to copy into a host app and then rename labels, URLs, and query wiring as needed.

Controller setup:

```ruby
class LegacyOrdersController < ApplicationController
  def index
    @table_key = :legacy_orders
    @table_preference_name = params[:table_preference_name].presence || "default"
    @table_columns = legacy_order_table_columns
    @table_preference_settings = rails_table_preference_settings(
      table_key: @table_key,
      name: @table_preference_name,
      fallback: {}
    )

    preference_params = rails_table_preference_params(
      table_key: @table_key,
      name: @table_preference_name,
      columns: @table_columns
    )
    merged_params = params.to_unsafe_h.merge(preference_params)

    @orders = Order
      .search(merged_params)
      .order_by(merged_params["sort"] || params[:sort])
      .page(params[:page])

    @table_preference_collection_url = "/rails_table_preferences/preferences/#{@table_key}"
    @table_preference_url = "#{@table_preference_collection_url}/#{ERB::Util.url_encode(@table_preference_name)}"
  end

  private

  def legacy_order_table_columns
    [
      table_preferences_column(
        :order_no,
        label: "受注番号",
        sortable: true,
        default_width: 140
      ),
      table_preferences_column(
        :customer_name,
        label: "得意先名",
        filter: { type: :text, param: :search_word },
        sortable: true,
        default_width: 240,
        overflow: :ellipsis
      )
    ]
  end
end
```

View wiring:

```erb
<%= table_preferences_editor(
  table_key: @table_key,
  name: @table_preference_name,
  settings: @table_preference_settings,
  columns: @table_columns,
  title: "受注一覧の表示設定"
) %>

<div
  data-controller="rails-table-preferences"
  data-rails-table-preferences-table-key-value="<%= @table_key %>"
  data-rails-table-preferences-name-value="<%= @table_preference_name %>"
  data-rails-table-preferences-collection-url-value="<%= @table_preference_collection_url %>"
  data-rails-table-preferences-url-value="<%= @table_preference_url %>"
  data-rails-table-preferences-columns-value="<%= @table_columns.to_json %>"
  data-rails-table-preferences-settings-value="<%= @table_preference_settings.to_json %>">
  <table class="table">
    <thead>
      <tr>
        <th data-rails-table-preferences-column-key="order_no">受注番号</th>
        <th data-rails-table-preferences-column-key="customer_name">得意先名</th>
        <th>備考</th>
        <th>操作</th>
      </tr>
    </thead>
    <tbody>
      <% @orders.each do |order| %>
        <tr>
          <td data-rails-table-preferences-column-key="order_no"><%= order.order_no %></td>
          <td data-rails-table-preferences-column-key="customer_name"><%= order.customer_name %></td>
          <td><%= truncate(order.note, length: 40) %></td>
          <td><%= link_to "詳細", order_path(order) %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

Use this pattern when:

- the host app already has a shared `<table>` partial or builder that you do not want to replace
- some columns should stay fully host-app-owned, such as notes, badges, or action links
- the page still needs saved filter/sort state through `rails_table_preference_params(...)` or `table_preferences_hidden_fields(...)`

Keep these boundaries in mind:

- the gem owns the managed-column keys, saved settings payload, preset API calls, and the UI behavior attached to those managed cells
- the host app still owns the query, authorization, export action, unmanaged columns, and any URL changes when `config.mount_path` is not `/rails_table_preferences`

For the exact manual-root attribute list and controller-side rules, see [JavaScript controller notes](javascript_controller.md). For a longer practical screen example, see [Practical examples](examples.md).

Users can drag resize handles to change widths. Double-clicking a resize handle auto-fits the column to the currently rendered cells, similar to spreadsheet applications. The resulting width is stored as the normal column `width` setting when the preference is saved.

## 6. Configure overflow behavior when needed

Use `overflow:` to control what happens when text is wider than the configured column width:

```ruby
@table_columns = [
  table_preferences_column(:customer_name, label: "得意先名", default_width: 200, overflow: :ellipsis),
  table_preferences_column(:note, label: "備考", default_width: 320, overflow: :wrap),
  table_preferences_column(:code, label: "コード", default_width: 120, overflow: :clip)
]
```

Supported values:

- `:ellipsis` or `:truncate`: single-line hidden overflow with `...`
- `:clip`: single-line hidden overflow without `...`
- `:wrap`: multi-line wrapping
- `:nowrap`: single-line overflow without clipping

`default_truncate:` remains available as a backward-compatible way to enable ellipsis behavior.

## 7. Add filter and sort metadata when needed

Filters and sorts are saved as UI state. The host application is still responsible for executing database searches.

```ruby
@table_columns = [
  table_preferences_column(
    :customer_name,
    label: "得意先名",
    filter: { type: :text, param: :search_word },
    sortable: true,
    default_width: 240,
    overflow: :ellipsis
  ),
  table_preferences_column(
    :delivery_date,
    label: "納品日",
    filter: { type: :date, from_param: :from_date, to_param: :to_date },
    sortable: true,
    default_width: 140
  )
]
```

Controller integration example:

```ruby
preference_params = rails_table_preference_params(
  table_key: :orders,
  columns: @table_columns
)

merged_params = params.to_unsafe_h.merge(preference_params)

@orders = Order
  .search(merged_params)
  .order_by(merged_params["sort"] || params[:sort])
```

Existing search form integration example:

```erb
<%= table_preferences_hidden_fields(
  settings: @table_preference_settings,
  columns: @table_columns
) %>
```

If the page already has a normal GET search form, `table_preferences_hidden_fields(...)` is the shortest way to keep saved filter/sort UI state attached to that form submission without rewriting the rest of the search flow. See [Controller integration](controller_integration.md) for full controller-side examples, nested-param variants, and Ransack wiring.

### If the same screen also offers exports

When a CSV, Excel, or report action should follow the same saved visible columns and order, resolve an export payload in the export action and keep file generation in the host app:

```ruby
export_payload = rails_table_preference_export_payload(
  table_key: :orders,
  columns: @table_columns,
  name: params[:table_preference_name]
)
```

Use `export_payload["column_keys"]` for a lightweight ordered column list, or `export_payload["headers"]` and `export_payload["columns"]` when labels and metadata need to follow the selected preset. See [Export integration](export_integration.md) for the minimal list-to-export wiring.

### If the same screen also needs shared, role, or organization presets

Owner presets work without extra scope configuration. When the same table should also resolve shared, role, or organization presets, configure `scope_context_method` and return the same stable identifiers that the non-owner presets use as `scope_key`:

```ruby
RailsTablePreferences.configure do |config|
  config.scope_context_method = :table_preference_scope_context
end

class ApplicationController < ActionController::Base
  private

  def table_preference_scope_context
    {
      roles: current_user.roles.pluck(:key),
      organization: current_user.organization_id
    }
  end
end
```

Keep the regular editor path for owner presets, and let the host app or a separate admin flow create shared, role, or organization presets. See [Scoped presets](scoped_presets.md) for default resolution order, `scope_key` examples, and minimal operating patterns.

## 8. Hide columns from the preference UI

Use `ignored: true` for columns that should not appear in the user-facing editor:

```ruby
table_preferences_column(:internal_cost, label: "Internal Cost", ignored: true)
```

Or pass a blacklist when rendering:

```erb
<%= table_preferences_editor(
  table_key: :orders,
  columns: @table_columns,
  ignored_columns: [:internal_cost]
) %>
```

Columns whose labels cannot be resolved are also treated as ignored by default.

Ignored columns are removed from Rails Table Preferences settings, but the host application must also avoid rendering sensitive data in HTML.

## Next steps

- See [Practical examples](examples.md) for more realistic list-screen integrations.
- See [Controller integration](controller_integration.md) for saved filter/sort params and existing search form wiring.
- See [Export integration](export_integration.md) when export actions should follow the saved visible columns and order.
- See [Scoped presets](scoped_presets.md) when the same screen should resolve shared, role, or organization presets.
- See [Troubleshooting](troubleshooting.md) if the editor, API, CSS, or JavaScript does not behave as expected.
