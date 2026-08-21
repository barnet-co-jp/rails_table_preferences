# Host app integration guardrails

Read this before adding host-app code around Rails Table Preferences (RTP). The normal integration path should stay on RTP's public helpers, package entrypoints, and lifecycle events. Host code should not depend on RTP persistence internals or Stimulus implementation methods unless the application intentionally takes ownership of that behavior.

## Before writing custom integration code

Use the public surface first:

| Host app goal | Prefer | Avoid |
| --- | --- | --- |
| Resolve a saved preset outside a controller | `RailsTablePreferences.resolve_preference` | `RailsTablePreferences::Preference.find_by(...)` |
| Resolve normalized saved settings outside a controller | `RailsTablePreferences.resolve_settings` | reading `Preference#settings` through an ad-hoc query |
| Resolve settings inside a controller | `rails_table_preference_settings` | duplicating preset/default/scope resolution |
| Convert saved filters/sorts to host params | `rails_table_preference_params` / `rails_table_preference_merged_params` | parsing the settings JSON into query params by hand |
| Build export column order/visibility | `rails_table_preference_export_payload` | parsing saved `columns` directly |
| Keep table header layout and editor layout aligned | package entrypoint's same-`table_key` layout sync | finding sibling Stimulus controllers in host code or overriding resize/drag internals only to copy `width` / `order` |
| React after save/load/delete | package lifecycle events | overriding async controller internals such as `withBusyStatus` |
| React to header sort/filter changes | `rails-table-preferences:state-changed` | overriding `toggleSortFromHeader`, `applyFilterPanel`, or `clearFilter` only to observe state |
| Type package integration | shipped `.d.ts` declarations | declaring RTP controller implementation methods as a host-owned public API |

## Controller-independent preset resolution

ViewComponents, helpers, presenters, export services, and other host-owned objects may need the same preset resolution semantics as controllers. Use the module API rather than querying the RTP model directly:

```ruby
settings = RailsTablePreferences.resolve_settings(
  owner: current_user,
  table_key: :orders,
  name: params[:table_preference_name],
  scope_context: {
    roles: current_user.roles.pluck(:key),
    organization: current_user.organization_id
  },
  fallback: {}
)
```

`resolve_preference` and `resolve_settings` use the same owner / role / organization / shared resolution behavior as the controller helpers. This keeps `default_flag`, the `default` fallback, scope priority, and normalization inside RTP.

## Table and editor column layout sync

When the packaged controller is used for both a table root and an editor root with the same `table_key`, RTP keeps column layout changes aligned in both directions.

Editor apply actions continue to synchronize the complete normalized settings snapshot to matching table roots. In the other direction, table-header resize, auto-fit, and drag-reorder completion synchronize only column `width` and `order` to matching roots. The receiving editor keeps its own in-progress values for visibility, truncation, filters, sorts, and other settings instead of replacing the whole editor draft.

This means a host application should not search the DOM for a paired RTP Stimulus controller, call `application.getControllerForElementAndIdentifier(...)`, or override `stopColumnResize`, `autoFitColumnFromHandle`, or `endTableColumnDrag` only to copy layout values. If the host deliberately replaces the packaged controller, it also takes ownership of that synchronization behavior.

The layout synchronization channel is an RTP implementation detail, not a host navigation or business-event API. Host code that needs to observe documented user-facing state changes should continue to use the lifecycle events below.

## Header state change event

The package entrypoint dispatches:

```text
rails-table-preferences:state-changed
```

when a header sort or filter operation actually changes settings. `event.detail.action` is one of:

- `sort-change`
- `filter-change`
- `filter-clear`

The event detail also contains the normal `tableKey`, preset `name`, and normalized settings snapshot used by the other package lifecycle events.

A host application that wants to round-trip table state through URL params or Turbo navigation should listen for this event and translate the supplied settings into its own navigation/query contract. RTP still does not own host database query execution or route semantics.

```js
element.addEventListener("rails-table-preferences:state-changed", (event) => {
  const { action, settings } = event.detail
  // Translate settings into host-owned URL/search params here.
})
```

## Responsibility boundary

RTP owns preset persistence/resolution, normalized display settings, same-table column-layout synchronization, adapter params, export column payloads, and the documented package lifecycle surface. The host application owns authorization, actual database queries, URL conventions, Turbo navigation, CSV/XLSX generation, and business-specific behavior.

If the host app appears to need an RTP model query or an override of an undocumented JavaScript method, first check the decision guide and this guardrail. If the public surface cannot express the requirement, treat that as a candidate RTP extension point rather than immediately coupling the host app to internals.
