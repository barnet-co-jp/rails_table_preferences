# Mounted JSON API

Rails Table Preferences exposes a small JSON API from the mounted engine. The bundled editor uses this API to list, load, save, and delete table preference presets.

Use this guide when a host app copies the bundled UI, writes integration tests around the mounted engine, or needs to understand the owner preset payload shape. The host app still owns authentication, authorization, routing around the mounted engine, and any business-specific query behavior.

The mounted API accepts writes only for owner presets. For non-owner scoped preset management, follow [Scoped presets](scoped_presets.md#minimal-operating-patterns) and use a host-app-owned seed, admin form, service object, or maintenance path. List and normal named/default resolution only return non-owner presets made available by the current scope context. An explicitly scoped read addresses the requested stored scope directly, so host applications that expose that form must authorize it through the configured parent controller.

## Route shape

Mount the engine in the host application:

```ruby
mount RailsTablePreferences::Engine, at: "/rails_table_preferences"
```

With that mount path, the engine routes are:

```text
GET    /rails_table_preferences/preferences/:table_key
POST   /rails_table_preferences/preferences/:table_key
GET    /rails_table_preferences/preferences/:table_key/:name
PATCH  /rails_table_preferences/preferences/:table_key/:name
PUT    /rails_table_preferences/preferences/:table_key/:name
DELETE /rails_table_preferences/preferences/:table_key/:name
```

`:table_key` identifies the table surface, such as `orders` or `warehouse_stocks`. Dots are valid inside the table key, so a logical surface such as `orders.index` routes as `/rails_table_preferences/preferences/orders.index` instead of treating `.index` as a response format. Slashes still split path segments, so use a stable key that does not depend on nested URL paths. `:name` identifies the preset name. When a request omits `name` in the body, the controller falls back to `preference_name` and then to `default`.

## URL source of truth

The bundled helpers build the editor and table root JSON API URLs from `RailsTablePreferences.configuration.mount_path`. Keep that initializer value synchronized with the path used when mounting the engine in `config/routes.rb`.

For example, a host app that mounts the engine at a tenant-scoped path should configure the same path:

```ruby
# config/routes.rb
mount RailsTablePreferences::Engine, at: "/tenant/preferences_engine"
```

```ruby
# config/initializers/rails_table_preferences.rb
RailsTablePreferences.configure do |config|
  config.mount_path = "/tenant/preferences_engine"
end
```

With that configuration, `table_preferences_editor` and `table_preferences_table_tag` emit URLs such as `/tenant/preferences_engine/preferences/orders`. `table_key` and preset `name` are URL-encoded by the helper before they are written into the `collectionUrl` and `url` data values.

Do not rely on route helper names as the public source of truth for these bundled JSON API URLs. If Save returns 404 after using a custom mount path, compare the rendered `data-rails-table-preferences-collection-url-value` / `data-rails-table-preferences-url-value` with the engine mount path first.

## List presets

Request:

```http
GET /rails_table_preferences/preferences/orders
```

Response:

```json
{
  "table_key": "orders",
  "preferences": [
    {
      "table_key": "orders",
      "name": "default",
      "default": true,
      "scope_type": "owner",
      "scope_key": null,
      "scope_label": "owner",
      "editable": true,
      "settings": {
        "columns": [],
        "filters": {},
        "sorts": []
      }
    }
  ]
}
```

The list includes preferences available to the current owner and scope context. See [Scoped presets](scoped_presets.md) for the owner/shared/role/organization resolution rules.

If the list includes shared, role, or organization presets, treat those records as readable choices for the editor. Creating or updating those records should happen through a host-app admin path, seed task, service object, or maintenance script that enforces the application's authorization and tenant rules.

## Load one preset

Request:

```http
GET /rails_table_preferences/preferences/orders/default
```

Response:

```json
{
  "table_key": "orders",
  "name": "default",
  "default": false,
  "scope_type": "owner",
  "scope_key": null,
  "scope_label": "owner",
  "editable": true,
  "settings": {
    "columns": [],
    "filters": {},
    "sorts": []
  }
}
```

When `name` is `default` and no explicit `scope_type` or `scope_key` is provided, the controller resolves the effective default preference for the current owner and scope context. For other names, it resolves the available named preference with the normal scope priority.

A missing default without explicit scope still returns `200 OK` with an empty normalized settings payload so a first-time table can open the bundled editor. A missing non-default named preset, or a missing preset requested with explicit `scope_type` / `scope_key`, returns `404 Not Found` with `{ "error": "not_found", "message": "Preference not found" }` so clients do not treat an absent explicit preset as a successful load.

## Create an owner preset

Request:

```http
POST /rails_table_preferences/preferences/orders
Content-Type: application/json
```

```json
{
  "name": "compact",
  "default": true,
  "settings": {
    "columns": [
      { "key": "order_no", "visible": true, "order": 10, "width": 120 }
    ],
    "filters": {
      "status": { "operator": "in", "values": ["open"] }
    },
    "sorts": [
      { "key": "delivery_date", "direction": "desc" }
    ]
  }
}
```

Response status: `201 Created`

```json
{
  "table_key": "orders",
  "name": "compact",
  "default": true,
  "scope_type": "owner",
  "scope_key": null,
  "scope_label": "owner",
  "editable": true,
  "settings": {
    "columns": [
      { "key": "order_no", "visible": true, "order": 10, "width": 120 }
    ],
    "filters": {
      "status": { "operator": "in", "values": ["open"] }
    },
    "sorts": [
      { "key": "delivery_date", "direction": "desc" }
    ]
  }
}
```

For the normal user-facing editor path, omit `scope_type` and `scope_key` so the preset is stored as an owner preset for the configured current-owner method.

## Update an owner preset

Request:

```http
PATCH /rails_table_preferences/preferences/orders/compact
Content-Type: application/json
```

```json
{
  "settings": {
    "columns": [
      { "key": "order_no", "visible": true, "order": 10, "width": 160 }
    ],
    "filters": {},
    "sorts": []
  }
}
```

Response status: `200 OK`

The response body uses the same preference payload shape as create and show.

Use `PUT` for the same update behavior when that is easier for the host app or test client.

## Delete an owner preset

Request:

```http
DELETE /rails_table_preferences/preferences/orders/compact
```

Response status: `204 No Content`

Deleting a missing preset is still a no-content response from the mounted controller. If a callback or database constraint prevents deletion, the API returns `422 Unprocessable Entity` with `error: "destroy_failed"`; the bundled editor keeps its action-specific delete failure status.

## Error responses

The API uses a small, stable JSON error envelope for request and persistence failures:

| Status | `error` | Meaning |
| --- | --- | --- |
| `400 Bad Request` | `invalid_request` | The route identity is blank, including a blank `table_key`. |
| `401 Unauthorized` | `owner_required` | An owner-scoped create, update, or delete was attempted without a configured current owner. Read-only shared/scoped preset reads remain available. |
| `403 Forbidden` | `owner_scope_required` | A mounted API write requested a shared, role, or organization scope. Use a host-owned admin service, seed, or maintenance path instead. |
| `404 Not Found` | `not_found` | An explicitly requested preset does not exist. Missing deletes remain idempotent `204` responses. |
| `422 Unprocessable Entity` | `validation_failed` | A create or update failed model validation, including duplicate names or invalid scope metadata. |
| `422 Unprocessable Entity` | `destroy_failed` | A destroy callback or persistence constraint prevented deletion. |

Validation and destroy errors include a `details` object keyed by model attribute. Clients should use `error` as the machine-readable contract and treat `message` and `details` as display/support context. Successful response payloads are unchanged.

New preset names are trimmed before persistence, and name comparison remains case-sensitive. Lookup first honors an exact legacy name and then tries its trimmed form, so records created by older versions with surrounding whitespace remain loadable and deletable. Updating such a legacy record normalizes its stored name; if that collides with an existing normalized name, the API returns the standard `422 validation_failed` response instead of silently merging records.

## Request fields

| Field | Used by | Meaning |
| --- | --- | --- |
| `name` | create/update body | Preset name. Route `:name` is used for show/update/delete; body `name` is mainly for create. |
| `preference_name` | create/update body | Backward-compatible alias for `name`. |
| `default` | create/update body | Boolean. When true, other defaults in the same table/scope are cleared. |
| `settings` | create/update body | Preference settings payload. It is normalized before persistence. |
| `scope_type` | create/update/show/delete query or body params | Defaults to `owner`. Writes reject any other value; reads may use a non-owner scope to request a specific preset. |
| `scope_key` | show query param | Scope identifier for an explicitly scoped role or organization read. It is not accepted as a non-owner write path. |

For owner writes, omit `scope_type` or send `"owner"`. The controller writes the preference against the configured current owner. A write with `scope_type` set to `shared`, `role`, or `organization` returns `403 Forbidden` with `error: "owner_scope_required"`.

The `scope_type` and `scope_key` fields remain the storage and resolver contract for non-owner presets. Create and maintain those records through host-owned seeds, internal forms, service objects, or maintenance scripts so application-specific authorization and tenant rules remain explicit.

## Response fields

| Field | Meaning |
| --- | --- |
| `table_key` | Table surface requested in the route. |
| `name` | Preset name returned by the resolver. |
| `default` | Whether the stored preference is marked as the default in its scope. |
| `scope_type` | `owner`, `shared`, `role`, or `organization`. |
| `scope_key` | Scope identifier, or `null` when the stored preference has none. |
| `scope_label` | Label supplied by the stored preference, falling back to the scope type. |
| `editable` | True when the current owner may edit the returned preference. Non-owner presets are returned as non-editable in the normal editor path. |
| `settings` | Normalized preference settings, including `columns`, `filters`, and `sorts`. |

## Scope and authorization boundary

The mounted engine inherits the configured parent controller, so host applications should protect the mounted route with the same authentication and authorization posture used for the surrounding app.

The owner preset API shape above is the stable write path used by the bundled editor. The mounted API rejects shared, role, and organization writes with `403 Forbidden`. This makes the mounted route safe from non-owner mutation without requiring parameter-aware write authorization in the parent controller.

List and normal named/default resolution apply the configured scope context. Explicitly scoped reads address the requested stored scope directly and therefore still require host-app authorization through the configured parent controller when exposed to untrusted callers.

For shared, role, or organization preset operating patterns, keep using the guidance in [Scoped presets](scoped_presets.md): regular users save owner presets, while host applications provide an explicitly authorized admin form, service object, seed, or maintenance path for non-owner presets.
