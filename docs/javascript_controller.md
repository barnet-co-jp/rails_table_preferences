# JavaScript controller notes

The bundled Stimulus controller is intentionally small and replaceable. Host applications can use the packaged entrypoint, edit the copied file, or replace it with another controller registered as `rails-table-preferences`.

For import paths and Vite / `app/frontend` setup, see [JavaScript entrypoints](javascript_entrypoints.md).

## Responsibilities

The default controller currently handles:

- editor row rendering
- preset loading, saving, creating, deleting, and resetting
- column visibility
- column order from editor row drag-and-drop
- direct table header column reordering
- column width resizing
- text truncation application
- filter button and filter panel UI
- saved filter condition updates
- sortable header click UI with Shift-modified secondary sorting
- visible sort indicators, primary `aria-sort`, and sort-priority descriptions

## Event boundaries

The table header may support multiple interactions at once:

- header click: sort toggle when the column is sortable
- header drag: column order change
- right-edge handle drag: column width resize
- filter button click: filter panel open/close

The controller keeps these separate through `shouldIgnoreHeaderAction(target)`. Header sort and drag actions should ignore:

- resize handles
- filter buttons
- buttons
- inputs
- selects
- textareas

The sort handler also ignores active drag and resize operations.

Column resizing uses Pointer Events for the right-edge handle (`pointerdown`, `pointermove`, `pointerup`, and `pointercancel`) so mouse, touch, and pen input share the same width update path. The handle sets `touch-action: none` on its hit area to keep touch resizing from turning into page scroll or header drag, while double-click auto-fit stays on the separate `dblclick` path.

## Cross-root settings synchronization

The editor and table helpers normally render sibling `rails-table-preferences` controller roots. Apply, Reset, Show all columns, successful Save/Create/Load/Delete operations, and the package controller's clear-filters-and-sorts action broadcast an internal settings snapshot. Connected table roots with the same `tableKey` apply that snapshot immediately and follow the active preset name and URL.

Synchronization deliberately targets table roots only. Another editor with the same `tableKey` keeps its draft and dirty state, a different `tableKey` is ignored, and the source root does not reapply its own event. Disconnect removes the listener so Turbo reconnects do not accumulate updates. Treat this internal synchronization event as controller plumbing rather than a host-app lifecycle API; host integrations should continue to use the packaged public events below.

The synchronization bus is document-local. It does not cross iframes, browser tabs, or windows. When Turbo replaces a frame or page region, the disconnected root stops receiving updates and a newly connected root starts from its server-rendered settings before receiving later broadcasts; updates emitted while no matching table root is connected are not replayed. Keep the server-rendered `settings` and preset `name` aligned for each Turbo response instead of relying on the internal event as persistent state.

Use a distinct `table_key` when two tables on one page should not share display state. `editor_instance_key` controls generated editor element IDs and is not a synchronization routing key.

## Host app lifecycle events

The packaged controller entrypoint dispatches a small set of bubbling Stimulus events from the controller root after user-facing preference operations finish:

These lifecycle events are a package-entrypoint surface. Host applications that register the generated copied controller directly from `app/javascript/controllers/rails_table_preferences_controller.js` should not assume these events are present unless they port the same behavior into the copied or replacement controller. Use [Package-only controller boundary](javascript_entrypoints.md#package-only-controller-boundary) when deciding which registration path owns event listener QA.

- `rails-table-preferences:applied` after editor settings are applied to the current table without saving, or after the bundled clear-filters-and-sorts action clears filter/sort state
- `rails-table-preferences:saved` after an existing preset save or save-as-new request succeeds
- `rails-table-preferences:loaded` after a selected preset is loaded and applied
- `rails-table-preferences:deleted` after an editable preset is deleted and the controller returns to the default preset
- `rails-table-preferences:error` after load, save, create, delete, or initial preset-list loading fails

Representative listener:

```js
document.addEventListener("rails-table-preferences:saved", (event) => {
  const { tableKey, name, action, settings } = event.detail
  // Update host-app analytics, export previews, or surrounding UI here.
})
```

TypeScript host apps can import the packaged event-specific helper type and narrow each DOM event to the matching `CustomEvent` detail at the listener boundary:

```ts
import type { RailsTablePreferencesEventDetailFor } from "rails_table_preferences"

document.addEventListener("rails-table-preferences:saved", (event) => {
  const { tableKey, name, action, settings } = (event as CustomEvent<RailsTablePreferencesEventDetailFor<"rails-table-preferences:saved">>).detail

  // Success events expose the current settings snapshot after the operation succeeds.
  window.appAnalytics?.track("table_preference_saved", {
    table_key: tableKey,
    preset_name: name,
    action,
    visible_column_count: settings.columns?.filter((column) => column.visible !== false).length ?? 0
  })
})

document.addEventListener("rails-table-preferences:error", (event) => {
  const { tableKey, name, action, message } = (event as CustomEvent<RailsTablePreferencesEventDetailFor<"rails-table-preferences:error">>).detail

  // Error events expose a display-safe message, not the raw Error object.
  window.appAnalytics?.track("table_preference_error", {
    table_key: tableKey,
    preset_name: name,
    action,
    message
  })
})
```

Use `RailsTablePreferencesEventDetailFor<"rails-table-preferences:saved">` or the underlying `RailsTablePreferencesEventDetailMap` when listener code needs the event name to select the detail shape. The broader `RailsTablePreferencesEventDetail` union remains available for shared handlers that intentionally handle both success and error details.

Each event detail includes the stable `tableKey`, `name`, and current `settings` snapshot. Success events also include an `action` such as `apply`, `clear-filters-and-sorts`, `save`, `create`, `load`, or `delete`. The `error` event includes a stable `action` and display-safe `message`; it does not expose DOM nodes or the raw `Error` object.

The `rails-table-preferences:error` `action` values are stable operation labels for package-entrypoint diagnostics and UI sync. Current values are `load-presets` for initial preset-list loading, `load` for selected preset loading, `save` for updating an editable preset, `create` for save-as-new or owner fallback creation, `delete` for editable preset deletion, and fallback `operation` when an error is reported outside a named preference operation. When a future package-entrypoint operation adds another public error action, update this list and the source-level lifecycle event specs with that action.

Save-as-new and update-save both use `rails-table-preferences:saved`; distinguish them through `event.detail.action` (`create` vs `save`). Success events are dispatched only after the corresponding operation succeeds. Failure paths keep using the existing status region and busy-state behavior, and they dispatch only `rails-table-preferences:error`.

The bundled `clearFiltersAndSorts` action uses `rails-table-preferences:applied` with `event.detail.action === "clear-filters-and-sorts"` after it sets `settings.filters` to `{}` and `settings.sorts` to `[]`. It follows the existing busy guard and does not dispatch while busy. Button placement and action grouping remain outside this lifecycle surface; handle them through #560/#989 or host-owned UI work.

Host apps can keep adoption code small by choosing one surrounding concern and reading only the existing detail fields. For example, an analytics integration can record successful preset saves without coupling to controller internals or changing the payload contract:

```js
document.addEventListener("rails-table-preferences:saved", (event) => {
  const { tableKey, name, action, settings } = event.detail

  window.appAnalytics?.track("table_preference_saved", {
    table_key: tableKey,
    preset_name: name,
    action,
    visible_column_count: settings.columns.filter((column) => column.visible !== false).length
  })
})
```

The analytics provider, event naming, export preview refresh, and any surrounding toolbar state remain host-app responsibilities. Rails Table Preferences only provides the lifecycle event and current settings snapshot after the preference operation succeeds.

## Bundled sort boundary

A normal bundled header activation manages one active sort at a time. Click, Enter, or Space cycles the activated column through ascending, descending, and clear, replacing `settingsValue.sorts` with a one-item array or an empty array.

Hold Shift during the same activation to preserve other sort entries and add, reverse, or clear the selected column. The ordered array defines priority: the first item is primary, and later items are secondary. Only the primary header receives `aria-sort`; every active sort keeps its visible indicator and receives an `aria-description` containing the one-based priority. Adapters that only support one sort field should deliberately reduce the array at their existing mapping boundary.

## Bundled filter panel contract

The default filter panel stays intentionally lightweight.

- The triggering filter button owns `aria-expanded` and `aria-controls` while its panel is open.
- Opening the panel moves focus into the first bundled filter field.
- Pressing `Escape` closes the panel and returns focus to the triggering filter button.
- Clicking outside still closes the panel.
- Scroll and viewport resize also close the panel so the body-mounted panel does not drift away from its header context.
- Static `select` filters with many `options:` keep the browser `<select multiple>` control and add a small in-panel search field when the option count reaches the bundled threshold.
- The select option search only filters rendered static options in the open panel. It does not change saved filter values, adapter params, query execution, remote option loading, or dependent select behavior, and selected options remain visible even when they do not match the current search text.
- Screens that need autocomplete, async option loading, grouped option UX, virtualized selects, or host-specific authorization/scoping should keep that UI in a copied/custom controller or host-owned widget.
- The bundled controller does not add a full popover library, focus trap, modal dialog abstraction, remote search endpoint, or richer select dependency.
- For Tab / Shift+Tab leaving the panel, use [Filter panel keyboard boundary](filter_panel_keyboard_boundary.md) to decide whether normal browser focus movement is acceptable or the host app needs copied/replacement controller behavior.

## Table-only application rule

Column display effects must be applied only to cells inside the target table. This prevents editor rows from being affected when they use the same `data-rails-table-preferences-column-key` values as table cells.

The controller should use:

```js
const table = this.tableElement
return table.querySelectorAll(`[data-rails-table-preferences-column-key="${CSS.escape(key)}"]`)
```

It should not apply display, width, or truncation changes by querying the entire controller element.

## Minimal DOM contract for helper-free tables

When a host app keeps its own `<table>` markup, the bundled controller still works as long as the DOM contract stays intact.

- The controller root may be the `<table>` itself, or another element that contains the target `<table>`.
- When the root is not a table, the controller uses the first nested `<table>` as its target table.
- Managed headers and cells must expose matching `data-rails-table-preferences-column-key` values.
- Sort, filter, resize, reorder, and pinned-column behavior only apply to managed headers/cells inside that target table.
- Columns without `data-rails-table-preferences-column-key` stay under normal host-app control.

Managed column keys must be unique within the same logical table screen. Rails Table Preferences uses each column key as the shared identity for display settings, filters, sorts, export payload metadata, and DOM hooks. If two managed columns use the same key, saved column state is merged by that key and the controller cannot safely treat the two columns as separate identities by label, position, or cell content. When migrating helper-free tables, resource-table partials, or copied markup, check that each managed header/cell pair uses a distinct `data-rails-table-preferences-column-key` in that target table.

This is the supported path for server-rendered tables that come from an existing partial, Markdown/HTML rewrite, or another renderer that cannot directly use `table_preferences_table_tag(...)`.

## Coexisting table controllers

`table_preferences_table_tag(...)` can share the table root with host-app Stimulus controllers. Pass the host controller names through `data: { controller: ... }`; the helper keeps them and appends `rails-table-preferences` once.

```erb
<%= table_preferences_table_tag(
  table_key: :orders,
  columns: @table_columns,
  data: { controller: "orders-table row-selection" },
  class: "table"
) do %>
  ...
<% end %>
```

Rails Table Preferences still owns the `data-rails-table-preferences-*` values it emits. Host controllers should use their own data attributes for analytics, selection, inline editing, or other table-local behavior.

## Manual root values when bypassing the table helper

If the host app mounts the controller root manually instead of using the bundled table helper, provide the same core values that the controller reads from normal helper output:

- `data-controller="rails-table-preferences"`
- `data-rails-table-preferences-table-key-value`
- `data-rails-table-preferences-collection-url-value`
- `data-rails-table-preferences-url-value`
- `data-rails-table-preferences-columns-value`
- `data-rails-table-preferences-settings-value`
- `data-rails-table-preferences-name-value` when the same screen renders the bundled editor or preset select

Treat these values as one logical table contract. The `table_key`, `columns`, and `settings` values should come from the same table definition, the collection/member URL values should point at the same mounted preferences endpoint, and the optional `name` value should match the preset name shown by the editor or preset select. If the table and editor are rendered from different partials, pass the same values into both partials instead of recomputing them independently.

Optional UI labels such as `data-rails-table-preferences-filter-label-value`, `data-rails-table-preferences-filter-operator-labels-value`, and `data-rails-table-preferences-sort-asc-label-value` can also be overridden when the host app needs localized copy different from the defaults.

Use `data-rails-table-preferences-filter-operator-labels-value` with a JSON object when only operator wording needs to change. Keys are operator names, and values are the labels used by both the filter panel select options and active filter summaries:

```erb
data-rails-table-preferences-filter-operator-labels-value='<%= { contains: "含める", equals: "完全一致" }.to_json %>'
```

Operators omitted from the object keep the bundled Japanese defaults. Unknown custom operator names fall back to the operator string unless the object provides a label for that key. This root value changes display wording only; filter metadata, saved settings shape, adapters, and query execution remain host-app responsibilities.

When the page also renders the bundled editor or preset select, pass `data-rails-table-preferences-name-value` too so the helper-free table root stays aligned with the current preset name. The controller can still mount without `name`, but preset save/load evidence is harder to interpret when the editor and table disagree about the current preset.

Example manual root wiring:

```erb
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

Notes:

- `order_no` and `customer_name` are managed by Rails Table Preferences because both header and body cells expose matching column keys.
- `備考` and `操作` stay fully host-app-owned because they do not expose `data-rails-table-preferences-column-key`.
- The URL values above assume the default mount path. If the host app mounts the engine elsewhere, change both URLs to the mounted path that serves `/preferences/:table_key`.
- The example intentionally reuses `@table_preference_settings` from `rails_table_preference_settings(...)` and the same column definitions the host app passes to `table_preferences_editor(...)`.
- If the helper-free table and editor/preset select live in different partials, record that both partials receive the same `table_key`, `name`, `columns`, `settings`, collection/member URLs, and managed column keys during PR smoke. A mismatch usually means the host app is rendering two different logical table contracts on one screen.

## Bundled editor copy override path

The bundled editor resolves most visible helper copy before the controller runs, in the ERB partial, through locale keys under `rails_table_preferences.editor`.

Representative keys include:

- `action_hint`
- `read_only_preset_hint`
- `loading_status`
- `saved_status`
- `deleting_failed_status`
- `reset_hint`

Representative controller-root label values include:

- `data-rails-table-preferences-filter-label-value`
- `data-rails-table-preferences-filter-apply-label-value`
- `data-rails-table-preferences-filter-clear-label-value`
- `data-rails-table-preferences-filter-operator-label-value`
- `data-rails-table-preferences-filter-operator-labels-value`
- `data-rails-table-preferences-filter-value-label-value`
- `data-rails-table-preferences-filter-from-label-value`
- `data-rails-table-preferences-filter-to-label-value`
- `data-rails-table-preferences-sort-asc-label-value`
- `data-rails-table-preferences-sort-desc-label-value`
- `data-rails-table-preferences-sort-clear-label-value`
- `data-rails-table-preferences-scope-owner-label-value`
- `data-rails-table-preferences-scope-shared-label-value`
- `data-rails-table-preferences-scope-role-label-value`
- `data-rails-table-preferences-scope-organization-label-value`

In practice that means:

- filter/sort labels, filter operator labels, and scope fallback labels can be overridden per controller root through `data-rails-table-preferences-*-label-value` or `data-rails-table-preferences-filter-operator-labels-value`
- bundled helper/status/reset wording is usually better changed through host-app locale entries
- copied ERB is only needed when the host app wants different markup, helper-text placement, or status-region structure
- copied or replacement JavaScript is still needed when the host app wants controller vocabulary or behavior that is not exposed as a root value, such as different busy-state logic

For a route-by-route decision guide and locale example, see [Accessibility baseline](accessibility.md).

## Stable table_key guideline

Use a `table_key` that identifies the logical screen or template, not a transient record id, request param, or DOM-generated UUID.

Good examples:

- `orders_index`
- `document_markdown_preview`
- `admin_customer_exports`

Avoid keys that change per request or per row, because saved presets, column order, and width history are keyed to that value.

## Saved column metadata rule

Current column definitions from the host application should remain authoritative for labels, filter metadata, sortable metadata, and column identity metadata. Saved preference records may contain old column settings, so merge logic should start from the current column definitions and then overlay user-owned state from saved settings. This keeps columns added after a preset was saved in the merged settings with their current default visibility, order, label, and metadata.

Current definitions remain authoritative for:

- `label`
- `filter`
- `sortable`
- `overflow`
- `pinned`

Saved settings should only override user-owned state such as visibility, order, width, truncation, filters, and sorts. If a host app wants a newly added column to start hidden for existing presets, set that default in the current column definition, for example `visible: false`, instead of treating saved presets as a migration target.

Column rename or removal cleanup is a separate compatibility decision; do not use the normal merge path as a saved preference migration framework.

## Filter and sort behavior

Filters and sorts update the in-memory `settingsValue` payload. Display-only settings can be applied to the current table immediately. Filter and sort execution usually requires the host application to run its own search query, reload, or submit a form.

Use the Ruby helpers and adapters for that part:

- `rails_table_preference_params`
- `rails_table_preference_merged_params`
- `table_preferences_params`
- `table_preferences_hidden_fields`
- `RailsTablePreferences::Adapters::ControllerParams`
- `RailsTablePreferences::Adapters::Ransack`

## Source-level safety specs

The project includes source-level specs for the Stimulus controller and package entrypoints, plus one narrow browser/system smoke for a demo-shaped screen. The source-level specs are not a replacement for broader browser/system coverage, but they still guard important invariants around the controller and package entrypoints.

Important invariants include:

- Japanese default UI labels remain available
- table cell effects are table-scoped
- filters and sorts are preserved by editor actions
- filter operator label overrides fall back to bundled defaults
- package-entrypoint lifecycle events expose stable event names and detail payloads without leaking raw `Error` objects
- clear filters/sorts lifecycle actions report the neutral filter/sort snapshot and keep the busy guard silent
- header controls do not accidentally trigger sort or drag
- sortable behavior is limited to `sortable: true` columns
- resize pointer move/up/cancel listeners are installed and cleaned up without falling back to mouse-only document listeners
- document listeners and detached filter panels are cleaned up
- `rails_table_preferences/controller` continues to export the bundled controller for Vite and other JS bundlers
