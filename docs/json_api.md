# Mounted JSON API

Rails Table Preferences exposes a small JSON API from the mounted engine. The bundled editor uses this API to list, load, save, and delete table preference presets.

Use this guide when a host app copies the bundled UI, writes integration tests around the mounted engine, or needs to understand the owner preset payload shape. The host app still owns authentication, authorization, routing around the mounted engine, and any business-specific query behavior.

For non-owner scoped preset management, use this page to understand the request and response shape, then follow [Scoped presets](scoped_presets.md#minimal-operating-patterns) for the host-app-owned seed, admin form, service object, or maintenance path. The regular editor route remains the owner-preset path for normal users; shared, role, and organization write policy belongs to the host application.

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

Deleting a missing preset is still a no-content response from the mounted controller.

## Request fields

| Field | Used by | Meaning |
| --- | --- | --- |
| `name` | create/update body | Preset name. Route `:name` is used for show/update/delete; body `name` is mainly for create. |
| `preference_name` | create/update body | Backward-compatible alias for `name`. |
| `default` | create/update body | Boolean. When true, other defaults in the same table/scope are cleared. |
| `settings` | create/update body | Preference settings payload. It is normalized before persistence. |
| `scope_type` | create/update/show/delete query or body params | Scope bucket. Defaults to `owner` when omitted. |
| `scope_key` | create/update/show/delete query or body params | Scope identifier for role or organization presets. Empty for owner and shared presets. |

For owner presets, do not send `scope_type` or send `"owner"`. The controller writes the preference against the configured current owner.

The `scope_type` and `scope_key` fields are the storage and resolver contract for non-owner presets, but they are not an authorization policy. When a host app uses them for shared, role, or organization presets, keep the write path outside the normal editor flow and protect it with app-specific admin authorization. Use the same parameter shape in seeds, internal forms, service objects, or maintenance scripts so admin-created records stay compatible with the resolver and list response.

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

The owner preset API shape above is the stable path used by the bundled editor. Non-owner scoped preset writes through the mounted JSON API are a product/security boundary under human review in [#496](https://github.com/matsuo-haruhito/rails_table_preferences/issues/496). Until that is decided, do not treat this guide as an admin API contract for creating or updating shared, role, or organization presets through the regular editor route.

For shared, role, or organization preset operating patterns, keep using the guidance in [Scoped presets](scoped_presets.md): regular users save owner presets, while host applications provide an explicit admin form, service object, seed, or maintenance path for non-owner presets.
