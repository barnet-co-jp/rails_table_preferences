# Troubleshooting

This guide lists common issues when installing or integrating Rails Table Preferences into a host Rails application.

Use this general troubleshooting guide for setup, controller registration, engine mount paths, owner lookup, migrations, helper-free roots, CSS, filter/sort integration, scoped presets, and customization boundaries. If the quick start or demo works but a real host-app index screen fails during save, reload, authentication, CSRF, duplicate-name, or `table_key` persistence flows, start with [Production troubleshooting notes](production_troubleshooting.md) and use this guide for the linked setup details.

## Choosing between troubleshooting guides

Use this map before changing runtime code:

- `404 Not Found` from Save/Load/Delete: start here with [Save returns 404](#save-returns-404), then confirm the production screen uses the same mount path and `config.mount_path`.
- `401`, `403`, or login redirects: start with [Production troubleshooting notes](production_troubleshooting.md#save-load-or-delete-returns-401-redirects-or-has-no-owner), then use [Save returns 401 or redirects to login](#save-returns-401-or-redirects-to-login) and [Save, Load, or Delete uses the wrong controller boundary](#save-load-or-delete-uses-the-wrong-controller-boundary) for the setup checks.
- `422 Unprocessable Entity` with authenticity-token logs: use [Production troubleshooting notes](production_troubleshooting.md#save-delete-or-save-as-new-returns-422) as the primary guide. This usually points to host-app layout or CSRF-token wiring, not a new Rails Table Preferences status-copy contract.
- Missing or nil owner: use [current_user is nil](#current_user-is-nil) for owner configuration and [Production troubleshooting notes](production_troubleshooting.md#save-load-or-delete-returns-401-redirects-or-has-no-owner) for real-screen symptom separation.
- Read-only scoped preset duplicate-name failures: use [Production troubleshooting notes](production_troubleshooting.md#saving-from-a-read-only-scoped-preset-fails-with-a-duplicate-name) as the primary guide, then use [Scoped preset exists but does not appear in the selector](#scoped-preset-exists-but-does-not-appear-in-the-selector) only if the preset never appears.
- Saved presets do not return on the same logical screen: use [Production troubleshooting notes](production_troubleshooting.md#saved-presets-do-not-come-back-on-the-same-screen) as the primary guide, then use [JavaScript controller notes](javascript_controller.md#stable-table_key-guideline) for the stable `table_key` source of truth.

## Stimulus controller does not run

Symptoms:

- The editor appears, but Apply/Save buttons do nothing.
- Dragging columns does nothing.
- Resize handles or filter buttons do not appear.
- Vite or another bundler reports `module not found` / `Failed to resolve import "rails_table_preferences/controller"`.

Check:

1. Choose the controller registration path for your frontend stack.

   With the default `stimulus-rails` manifest loader, the copied controller should exist in the host application:

   ```text
   app/javascript/controllers/rails_table_preferences_controller.js
   ```

   Files under `app/javascript/controllers` are usually registered automatically.

   With Vite / `app/frontend/entrypoints/application.js`, register the packaged controller explicitly. If the host app already starts Stimulus, reuse the existing `application` and only add the registration:

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

   If that import fails with a `module not found` or `Failed to resolve import` error, the bundler still cannot see the gem's packaged `app/javascript/rails_table_preferences/*` files. Add an alias or equivalent resolver for `rails_table_preferences` and `rails_table_preferences/controller`, then compare it with the minimal `vite.config.ts` example in [JavaScript entrypoints](javascript_entrypoints.md).

   With jsbundling or another custom Stimulus setup that uses the copied file, register it manually:

   ```js
   import RailsTablePreferencesController from "./controllers/rails_table_preferences_controller"
   application.register("rails-table-preferences", RailsTablePreferencesController)
   ```

2. The controller is registered as `rails-table-preferences`.

3. The rendered editor or table includes:

   ```html
   data-controller="rails-table-preferences"
   ```

4. The JavaScript file has no syntax errors:

   ```bash
   node --check app/javascript/controllers/rails_table_preferences_controller.js
   ```

See also [JavaScript entrypoints](javascript_entrypoints.md).

## Save returns 404

Symptoms:

- The editor appears, but Save fails.
- Browser devtools show a `404 Not Found` response for `/rails_table_preferences/preferences/...`.

Check that the engine is mounted:

```ruby
# config/routes.rb
mount RailsTablePreferences::Engine, at: "/rails_table_preferences"
```

If the engine is mounted at another path, also update the initializer:

```ruby
RailsTablePreferences.configure do |config|
  config.mount_path = "/your_custom_path"
end
```

The `mount_path` must match the route mount path because the helper builds the JSON API URLs from this value.

## Helper-free table root is missing required data values

Symptoms:

- The host app keeps its own table partial and mounts `data-controller="rails-table-preferences"` manually.
- Apply changes the editor state, but the rendered table does not update.
- Save uses an empty or unexpected URL, or writes to the wrong mounted path.
- Filter, sort, width, or visibility state resets because the controller starts with empty columns or settings.

Check the manually rendered controller root before changing runtime behavior:

1. Confirm the root has the same core values emitted by the bundled helper:

   - `data-rails-table-preferences-table-key-value`
   - `data-rails-table-preferences-collection-url-value`
   - `data-rails-table-preferences-url-value`
   - `data-rails-table-preferences-columns-value`
   - `data-rails-table-preferences-settings-value`

2. If the page also renders the bundled editor or preset select, confirm `data-rails-table-preferences-name-value` matches the current preset name.

3. Confirm the URL values use the actual mounted engine path. If the host app mounts the engine away from `/rails_table_preferences`, both manual URL values must use that custom path.

4. Confirm managed table headers and body cells still expose matching `data-rails-table-preferences-column-key` values. Missing root values and column-key mismatches can look similar, but the fixes are different.

For the full manual root example and the supported helper-free DOM contract, use [JavaScript controller notes](javascript_controller.md#manual-root-values-when-bypassing-the-table-helper) as the source of truth. Troubleshooting should identify the missing value; the controller should not be redesigned or given host-app-specific validation just to cover an incomplete manual root.

## Save returns 401 or redirects to login

Symptoms:

- Save/Load/Delete requests redirect to the login page.
- JSON requests return unauthorized responses.

Rails Table Preferences uses the host application's controller stack. Check:

- The mounted engine is accessible to logged-in users.
- `current_user` or the configured current-user method returns the owner object.
- Authentication filters in `ApplicationController` allow the JSON requests after login.

If the host application uses a different current user method, configure it:

```ruby
RailsTablePreferences.configure do |config|
  config.current_user_method = :current_customer
end
```

For real host-app index screens where the page renders but the mounted JSON API redirects, returns `401` / `403`, or has no owner, use [Production troubleshooting notes](production_troubleshooting.md#save-load-or-delete-returns-401-redirects-or-has-no-owner) to separate authentication, parent-controller, CSRF, and owner lookup failures before changing runtime behavior.

## Save, Load, or Delete uses the wrong controller boundary

Symptoms:

- Save/Load/Delete works on the page sometimes, but the mounted JSON request misses login, tenant, locale, or account setup.
- Requests return 401/403, redirect to login, or fail CSRF checks even though the surrounding host-app page loaded correctly.
- Scoped presets or owner lookup fail only through the mounted engine request.

The mounted JSON API inherits the controller named by `RailsTablePreferences.config.parent_controller_class_name`. Use the [Production integration checklist](production_integration_checklist.md#1-confirm-the-owner-and-engine-contract) as the source of truth, then check:

1. `parent_controller_class_name` points to the host controller that should own the mounted API boundary, such as `ApplicationController` or an authenticated base controller.
2. That parent controller runs the authentication, CSRF handling, tenant or locale setup, and other `before_action` callbacks the preference API needs.
3. `current_user_method` and, when scoped presets are enabled, `scope_context_method` are reachable from that same controller stack.
4. `config.mount_path` still matches the engine route, so the editor is not sending requests to a stale or unauthenticated endpoint.

Do not fix these symptoms by moving host-app authentication, authorization, or tenant policy into Rails Table Preferences. The gem owns the mounted preference API and editor payloads; the host app owns the controller stack and request-wide security boundary.

## current_user is nil

Symptoms:

- Preference API requests fail.
- Logs indicate a missing owner/user.
- The copied demo screen opens, but save/load/delete fails because no owner record is available.

By default, the gem calls `current_user`. If the host application uses another owner concept, configure both the owner model and the current-owner method:

```ruby
RailsTablePreferences.configure do |config|
  config.owner_model = :customers
  config.current_user_method = :current_customer
end
```

The method must return an instance of the configured owner model.

For quick sandbox or demo verification, make sure that method returns a persisted record:

```ruby
class ApplicationController < ActionController::Base
  helper_method :current_customer

  private

  def current_customer
    Customer.first_or_create!(name: "Sandbox Customer")
  end
end
```

The copied demo screen uses the same configured current-owner method as the normal editor flow. `--with-demo` does not seed `User`, `Customer`, or another owner model automatically.

For production screens, nil-owner symptoms often appear together with authentication redirects, parent-controller mismatches, or CSRF failures. Use [Production troubleshooting notes](production_troubleshooting.md#save-load-or-delete-returns-401-redirects-or-has-no-owner) as the symptom-driven checklist after confirming the owner configuration here.

## Migration references the wrong owner model

Symptoms:

- The generated migration uses `user_id`, but preferences should belong to customers, clients, accounts, or another model.

Generate with `--owner-model`:

```bash
bin/rails generate rails_table_preferences:install --owner-model customers
```

This produces `customer_id`. The value can be singular or plural:

```bash
bin/rails generate rails_table_preferences:install --owner-model client
bin/rails generate rails_table_preferences:install --owner-model clients
```

Override the foreign key only when the column name must differ from the owner model:

```bash
bin/rails generate rails_table_preferences:install --owner-model customers --owner-foreign-key member_id
```

## Migrating legacy ColumnAdjustment records

Use the legacy import task only when the host app already has `ColumnAdjustment` records that should become Rails Table Preferences records. It is not part of a normal new installation path.

Start with a dry run:

```bash
DRY_RUN=true bundle exec rake rails_table_preferences:legacy:import_column_adjustments
```

If legacy records do not point to the expected owner through `user`, `create_user`, `user_id`, or `create_user_id`, provide a default owner id for records that need it:

```bash
USER_ID=123 DRY_RUN=true bundle exec rake rails_table_preferences:legacy:import_column_adjustments
```

After reviewing the counts, run without `DRY_RUN=true` to write the imported preferences:

```bash
USER_ID=123 bundle exec rake rails_table_preferences:legacy:import_column_adjustments
```

The task prints:

- `created`: preferences that would be or were newly created
- `updated`: existing preferences that would be or were updated
- `skipped`: records that were not imported
- `imported`: `created + updated`

Skipped records can happen when no owner can be resolved, the legacy `value` cannot be parsed as JSON, the generated preference is invalid, the database statement fails, or the legacy record shape does not expose the expected methods. Investigate skipped records before using the imported settings in production.

The importer maps `table_name` to `table_key`, `setting_name` to the preference name, and the legacy `value` to normalized column settings. It does not create a rollback framework or host-app-specific migration UI.

## CSS is not applied

Symptoms:

- The editor appears unstyled.
- Editor inputs overlap or wrap poorly.

Check that the stylesheet exists in the host application:

```text
app/assets/stylesheets/rails_table_preferences.css
```

For asset-pipeline based apps, ensure the stylesheet is included by the application. For custom frontend setups, import or copy the CSS into the host application's stylesheet bundle.

You can copy the default stylesheet again:

```bash
bin/rails generate rails_table_preferences:stylesheets
```

Host applications are expected to customize CSS as needed.

## Column display changes do not affect the table

Symptoms:

- The editor rows change, but the actual table columns do not hide, resize, or reorder.

Each header and cell must have a matching `data-rails-table-preferences-column-key`.

Example:

```erb
<th data-rails-table-preferences-column-key="customer_name">得意先名</th>
<td data-rails-table-preferences-column-key="customer_name"><%= order.customer_name %></td>
```

The key must match the `table_preferences_column` key:

```ruby
table_preferences_column(:customer_name, label: "得意先名")
```

## resource_table_for raises model: only when there are no rows

Symptoms:

- `resource_table_for(@orders.to_a)` or `tree_resource_table_for(@projects.to_a)` works while rows exist.
- The same page raises `model: is required` only after a search, filter, or first render returns an empty plain array.

Relation-like collections such as `Order.where(...)` can be inferred even when empty because they expose `records.klass`. Plain arrays do not carry that model metadata once they are empty, and Rails Table Preferences does not guess from constants or global state.

Pass `model:` for empty plain arrays or manually assembled collections:

```erb
<%= resource_table_for(@orders.to_a, model: Order) %>
<%= tree_resource_table_for(@projects.to_a, model: Project) %>
```

A table profile with `model Order` also satisfies the same requirement:

```erb
<%= resource_table_for(@orders.to_a, profile: OrdersTableProfile) %>
```

For the broader model inference rules and empty collection examples, see [Resource table adapters](resource_tables.md#model-inference-and-empty-collections).

## Preset labels or helper text point to another editor instance

Symptoms:

- Clicking the preset select label in one editor focuses the select in another editor.
- Clicking the preset name label in one editor focuses the text input in another editor.
- The default preset checkbox reads helper text from another editor instance.
- A copied/customized partial works with one editor, but breaks after rendering two editors on the same page.

Check:

1. Confirm whether the host app still uses the bundled partial unchanged.

   The current bundled partial already generates per-render ids for the preset select, preset name, and default preset hint. If the host app did not copy/customize the partial, compare the rendered markup with the current `_editor.html.erb` output before assuming the helper/runtime contract is wrong.

2. Inspect each rendered editor and verify that these pairings stay local to the same instance:

   - preset select label `for` -> select `id`
   - preset name label `for` -> text input `id`
   - default preset checkbox `aria-describedby` -> helper text `id`

   The bundled partial currently generates ids with these suffixes:

   - `-preset-select`
   - `-preset-name`
   - `-default-preset-hint`

   If two editors render the same exact ids, first check whether both helper calls passed the same explicit `editor_instance_key:`. When you pass `editor_instance_key:`, keep it unique per rendered editor instance on the same page, for example `"orders-page"` and `"orders-dialog"`.

3. If the host app copied/customized the partial, look for hard-coded ids such as `preset-select`, `preset-name`, or `default-preset-hint`.

   The safe pattern is the same one documented in [Quick start](quick_start.md): preserve the label/input and helper-text relationships, but keep ids unique per rendered instance. If the copied partial needs stable ids across repeated renders, keep using the passed `editor_instance_key` local when building the bundled id prefix instead of replacing it with a static value.

4. Use `editor_instance_key:` only when the host app needs stable generated control ids.

   The helper exposes `editor_instance_key:` for drawers, dialogs, repeated renders, or tests that need predictable preset select/name/default hint ids. It is not a root element id/class/data/aria placement API. For root placement attributes, use [Editor root HTML options](editor_root_options.md) instead.

5. Re-run the narrow manual checks after adjusting the helper call or copied markup.

   Use the same checks already called out in [Accessibility baseline](accessibility.md) and [Manual QA checklist](manual_qa.md): render two editors, click each preset label, confirm focus stays inside the matching editor, and confirm each default preset checkbox describes only its local helper text.

## Double-click auto-fit does not change the expected width

Symptoms:

- Double-clicking the resize handle changes little or not at all.
- The fitted width is too small or too large.

Auto-fit measures the cells currently rendered in the browser, not all database rows. On paginated, lazy-loaded, or virtualized tables, it fits the visible page only.

The generated width is clamped by Stimulus values:

- `resizeAutoFitMinWidth`
- `resizeAutoFitMaxWidth`
- `resizeAutoFitPadding`

Override those data values on the rendered table/editor wrapper if the host app needs different bounds.

## Long text is clipped, wrapped, or ellipsized differently than expected

Symptoms:

- Text wraps when you expected a single line.
- Text is clipped without `...`.
- Text overflows outside the cell.

Use `overflow:` on the column definition:

```ruby
table_preferences_column(:customer_name, label: "得意先名", default_width: 200, overflow: :ellipsis)
table_preferences_column(:note, label: "備考", default_width: 320, overflow: :wrap)
table_preferences_column(:code, label: "コード", default_width: 120, overflow: :clip)
table_preferences_column(:external_id, label: "外部ID", default_width: 180, overflow: :nowrap)
```

Supported values are `:ellipsis`/`:truncate`, `:clip`, `:wrap`, and `:nowrap`. `default_truncate:` still enables ellipsis behavior for backward compatibility.

Host application CSS can still override inline or class-based behavior. Check local table styles if the configured overflow mode is not reflected.

## A column is missing from the editor

Symptoms:

- A column passed to `table_preferences_editor` does not appear in the column list.
- Saved filters/sorts for that column are also removed from the settings payload.

By default, Rails Table Preferences hides columns whose user-facing label cannot be resolved. The default label resolution order is:

1. Explicit `label:`
2. Explicit `i18n_key:`
3. Database column comment through `model.columns_hash[key].comment`

Fix by marking the column as user-facing in one of those ways:

```ruby
table_preferences_column(:customer_name, label: "得意先名")
table_preferences_column(:customer_name, i18n_key: "orders.index.columns.customer_name")
table_preferences_column(:customer_name, model: Order)
```

If you intentionally want unresolved columns to remain visible, configure a fallback:

```ruby
RailsTablePreferences.configure do |config|
  config.label_resolution = %i[label i18n_key column_comment humanize]
  # or:
  config.unresolved_label_behavior = :humanize
end
```

## Japanese labels are not shown

Symptoms:

- Column labels are missing from the editor.
- Columns disappear because no user-facing label was resolved.

By default, locale attribute keys are not used unless you opt in. Use `label:`, `i18n_key:`, or DB column comments first:

```ruby
table_preferences_column(:customer_name, label: "得意先名")
table_preferences_column(:customer_name, i18n_key: "orders.index.columns.customer_name")
table_preferences_column(:customer_name, model: Order)
```

If the host app wants Rails-style attribute locale keys, add those rules in the initializer:

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

Host app locale example:

```yaml
ja:
  activerecord:
    attributes:
      order:
        customer_name: 得意先名
```

## Filter or sort UI changes do not change database results

This is expected unless the host application applies saved filter/sort params.

Rails Table Preferences stores filter/sort UI state and can convert it to params, but it does not execute database queries. The host application must merge and apply those params.

Controller example:

```ruby
preference_params = rails_table_preference_params(
  table_key: :orders,
  columns: columns
)

merged_params = params.to_unsafe_h.merge(preference_params)

@orders = Order
  .search(merged_params)
  .order_by(merged_params["sort"] || params[:sort])
```

Existing search form example:

```erb
<%= table_preferences_hidden_fields(
  settings: @table_preference_settings,
  columns: columns
) %>
```

If a bundled select filter appears in the UI but the result set does not change, use [Select filter troubleshooting](select_filter_troubleshooting.md) to verify `values_param`, scalar `options:`, and host-app query ownership.

## Ransack params are not what you expect

Use `adapter: :ransack` when converting saved filters/sorts for Ransack:

```ruby
ransack_params = rails_table_preference_params(
  table_key: :orders,
  columns: columns,
  adapter: :ransack
)

@q = Order.ransack(params.fetch(:q, {}).to_unsafe_h.merge(ransack_params))
```

For forms, use `namespace: :q`:

```erb
<%= table_preferences_hidden_fields(
  settings: @table_preference_settings,
  columns: columns,
  adapter: :ransack,
  namespace: :q
) %>
```

## ignored columns still appear

`ignored_columns`, `ignored: true`, and unresolved labels remove columns from Rails Table Preferences' column editor and settings payload. They do not remove HTML that the host application explicitly renders.

If a value should not appear on screen, also remove it from the table markup and from the underlying query or serializer.

Example:

```ruby
columns = [
  table_preferences_column(:customer_name, label: "得意先名"),
  table_preferences_column(:internal_cost, label: "内部原価", ignored: true)
]
```

Do not render the ignored column in the table if users must not see it.

## Presets do not load or default preset is unexpected

When no preset name is passed, preference resolution uses this order:

1. A preset with `default_flag = true`
2. The preset named `default`
3. Empty normalized settings

Pass a preset name explicitly when the screen should use a specific preset:

```erb
<%= table_preferences_editor(
  table_key: :orders,
  name: params[:table_preference_name] || "default",
  columns: columns
) %>
```

## Scoped preset exists but does not appear in the selector

Symptoms:

- A role or organization preset was created, but it does not appear for the expected owner.
- The selector shows owner/shared presets only, even though a scoped preset record exists.
- The generated demo shows `共有ビュー [shared]`, but `担当ビュー [role:operations]` or an organization preset never appears.

Check:

1. Confirm `scope_context_method` is configured.

   ```ruby
   RailsTablePreferences.configure do |config|
     config.scope_context_method = :table_preference_scope_context
   end
   ```

   If the configuration is missing, Rails Table Preferences resolves only owner/shared presets.

2. Confirm the method actually runs for the current request and returns the expected shape.

   ```ruby
   def table_preference_scope_context
     {
       roles: current_user.roles.pluck(:key),
       organization: current_user.organization_id
     }
   end
   ```

   The method may be private, but it must be reachable from the controller stack used by the mounted engine and the demo screen.

3. Compare the runtime values with the saved `scope_key` exactly.

   Role and organization matching is string-based. Save the same stable identifier that the runtime context returns.

   Good matches:

   - `roles: ["operations"]` with `scope_type: "role"` and `scope_key: "operations"`
   - `organization: "tokyo-hq"` with `scope_type: "organization"` and `scope_key: "tokyo-hq"`

   Common mismatches:

   - role label like `"Operations Team"` saved in `scope_key`, while the runtime context returns `"operations"`
   - numeric `organization_id` returned at runtime, but a slug like `"tokyo-hq"` saved in `scope_key`
   - symbol-like values in app code that end up serialized differently from the stored string

4. Confirm the preset record was saved as a non-owner scoped preset.

   Shared, role, and organization presets should be stored with `user: nil` and the intended `scope_type` / `scope_key`.

   Example console checks:

   ```ruby
   RailsTablePreferences::Preference.where(
     table_key: "orders",
     scope_type: "role",
     scope_key: "operations",
     user: nil
   )
   ```

   ```ruby
   RailsTablePreferences::Preference.where(
     table_key: "orders",
     scope_type: "organization",
     scope_key: "tokyo-hq",
     user: nil
   )
   ```

5. If you are using the generated demo, remember that the role example appears only after you add the matching scope context.

   The copied demo seeds `担当ビュー` with `scope_type: "role"` and `scope_key: "operations"`. It stays hidden until the host app returns `roles: ["operations"]` from `scope_context_method`.

If the record exists and the context keys line up, but the selector still does not show the preset, compare the current host-app setup with [Scoped presets](scoped_presets.md) and inspect the request-time context values directly before changing the saved data.

## Need to customize the UI

The default ERB, CSS, and JavaScript are intentionally copy-based, while Vite apps can import the packaged controller entrypoint directly.

Copy views:

```bash
bin/rails generate rails_table_preferences:views
```

Copy stylesheet:

```bash
bin/rails generate rails_table_preferences:stylesheets
```

Copy JavaScript controller:

```bash
bin/rails generate rails_table_preferences:javascript
```

Host applications can edit copied files freely, or register their own controller as `rails-table-preferences`.
