# Scoped presets

Rails Table Preferences supports owner, shared, role, and organization scoped presets.

The feature is intended for applications that want one or more default table layouts to be provided by the application, an administrator, a role, or an organization, while still allowing each user to save personal overrides.

For the first non-owner preset, start with [Minimal operating patterns](#minimal-operating-patterns). Those patterns describe the host-app-owned setup path for seed data, admin forms, service objects, and maintenance scripts without turning Rails Table Preferences into an admin UI or authorization framework.

## Scope types

| Scope type | Meaning | Owner foreign key | Scope key |
| --- | --- | --- | --- |
| `owner` | A personal preset for the current owner, usually the current user. | Required | Empty |
| `shared` | A global preset available to all owners. | Empty | Empty |
| `role` | A preset available to owners whose scope context includes the role. | Empty | Required |
| `organization` | A preset available to owners whose scope context includes the organization. | Empty | Required |

The generated migration includes:

```ruby
t.references :user, null: true
t.string :scope_type, null: false, default: "owner"
t.string :scope_key
```

The owner reference is nullable because shared, role, and organization presets are not owned by a single user.

## Scope context

Configure a method that returns the current scope context:

```ruby
RailsTablePreferences.configure do |config|
  config.scope_context_method = :table_preference_scope_context
end
```

Then define the method in the parent controller:

```ruby
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

The method may be public or private. If no method is configured, the context is empty.

Role and organization preset matching is string-based. Use the same stable identifiers in `scope_key` that the configured scope context method returns.

When administrators create non-owner presets through a seed task, console script, internal admin form, or service object, store the same `scope_key` values that this method will return at request time. Rails Table Preferences owns the resolver contract; the host app owns the operation that creates those scoped records and the policy for who may change them.

## Default resolution order

When no preset name is explicitly requested, Rails Table Preferences resolves defaults in this order:

1. Owner default
2. Role default
3. Organization default
4. Shared default
5. Owner preset named `default`
6. Empty normalized settings

This lets an application provide a shared baseline while allowing users to override it by saving their own default preset.

## Named preset resolution

When a preset name is requested, Rails Table Preferences looks for available presets with that name using the same availability rules.

Available presets are:

- presets owned by the current owner
- shared presets
- role presets matching the configured role context
- organization presets matching the configured organization context

Because the stored uniqueness scope includes the table, owner, `scope_type`, and `scope_key`, a host app can store the same `name` in more than one scope bucket. For example, an owner preset named `default`, a shared preset named `default`, and a role preset named `default` can all exist for the same table when their scopes differ.

A requested named preset still resolves to one available record for the current request. If multiple scopes expose the same `name`, the resolver uses the same scope priority as defaults: owner first, then role, organization, and shared. Treat same-name presets as an explicit fallback pattern, not as a way to present several choices with identical labels in the bundled selector.

For admin seeds and maintenance scripts, prefer names that remain clear when they are listed together, such as `operations-default`, `tokyo-default`, or `shared-baseline`. If you intentionally reuse a name across scopes, document the intended fallback order in the host app so future admin changes do not accidentally shadow the preset a user expects to load.

## API parameters

Normal personal presets do not need any extra parameters:

```json
{
  "name": "default",
  "settings": { "columns": [] }
}
```

Create a shared preset:

```json
{
  "name": "team-default",
  "scope_type": "shared",
  "settings": { "columns": [] }
}
```

Create a role preset:

```json
{
  "name": "inspection",
  "scope_type": "role",
  "scope_key": "admin",
  "settings": { "columns": [] }
}
```

Create an organization preset:

```json
{
  "name": "tokyo-default",
  "scope_type": "organization",
  "scope_key": "tokyo",
  "settings": { "columns": [] }
}
```

## API response fields

Preference responses include scope metadata:

```json
{
  "table_key": "orders",
  "name": "team-default",
  "default": true,
  "scope_type": "shared",
  "scope_key": "",
  "scope_label": "shared",
  "editable": false,
  "settings": { "columns": [], "filters": {}, "sorts": [] }
}
```

`editable` is `true` for owner presets that belong to the current owner. Shared, role, and organization presets are returned as non-editable from the normal user-facing editor path.

## Scope label fallback and localization

The bundled editor has two sources for the user-facing owner/shared/role/organization label:

1. If a preset payload already includes `scope_label`, the selector shows that value.
2. Otherwise the copied editor falls back to the locale-backed labels passed through `app/views/rails_table_preferences/_editor.html.erb`.

The default fallback keys are:

- `rails_table_preferences.editor.scope_owner`
- `rails_table_preferences.editor.scope_shared`
- `rails_table_preferences.editor.scope_role`
- `rails_table_preferences.editor.scope_organization`

A host app can change those fallback labels through normal Rails locale overrides:

```yaml
ja:
  rails_table_preferences:
    editor:
      scope_owner: 個人設定
      scope_shared: 全体共有
      scope_role: ロール既定
      scope_organization: 組織既定
```

If the host app copies the bundled editor partial, it can also replace the `data-rails-table-preferences-scope-*-label-value` attributes directly. The locale keys are the shortest path when the bundled partial is still in use.

Custom or unknown `scope_type` values do not have locale-backed fallback labels in the bundled editor. If a host app returns a custom scope bucket from its own endpoint or payload transformer, include a user-facing `scope_label` in each preset payload. Without that value, the selector can only fall back to the raw `scope_type` key, which is useful for debugging but usually too internal for a production selector.

If the host app also provides its own preset endpoint, admin UI, or payload transformer that sets `scope_label`, keep that value aligned with the same wording. That prevents the preset selector from showing one label while nearby bundled fallback copy uses another.

## Preset selector grouping

When the preset collection includes more than one scope bucket, the bundled editor groups the native `<select>` options with `<optgroup>` in this order: owner, role, organization, shared, then any unknown scope types returned by a custom payload.

Within each group, options keep the API response order. Option text still keeps the existing `name [scopeLabel] *` pattern, and the option data attributes for default state, editability, scope type, and scope key are preserved. This makes the selector easier to scan without changing JSON response shape, resolver priority, save/delete behavior, or same-name preset resolution.

Unknown scope buckets keep that same display-only grouping behavior and are appended after the standard buckets. For those buckets, `scope_label` is the host-app-owned readable label; Rails Table Preferences does not infer final wording, add a fallback label map, or change resolver priority for custom scopes.

If only one scope bucket is present, the selector stays flat. That keeps the simple owner-only editor compact while still giving multi-scope screens a clearer grouping cue.

The grouping is a display aid, not a duplicate-name disambiguation feature. If a host app intentionally stores the same preset name in several scopes, the resolver still chooses one record by scope priority when that name is requested. Prefer clear preset names when users need to compare several presets in the selector.

## Recommended UI behavior

For user-facing screens:

- users may select shared, role, or organization presets
- users should save personal changes as owner presets
- non-owner presets should not be overwritten from the regular editor
- host applications may provide a separate admin screen for managing shared, role, or organization presets

## Minimal operating patterns

Use this section as the first-preset recipe for shared, role, and organization presets. The goal is to show how a host app can create and maintain scoped records while Rails Table Preferences continues to own only the storage, normalization, and resolver behavior.

Before choosing a pattern, decide four host-app-owned details:

- which table gets the first non-owner preset and which stable `table_key` identifies it
- which scope bucket owns the preset: `shared`, one or more `role` keys, or one `organization` key
- which protected path writes the preset: seed data, an internal admin form, a service object, or a maintenance script
- how that path proves authorization, tenant ownership, and audit needs outside the regular bundled editor

The following patterns keep the bundled editor simple while still giving the host application a clear place to manage non-owner presets.

### 1. Seed a shared baseline

A seed task, migration, or one-off setup script can bootstrap one shared default per table by storing the same payload shape that the JSON API accepts:

```ruby
shared_default_payload = {
  name: "operations-default",
  default: true,
  scope_type: "shared",
  settings: {
    columns: [],
    filters: {},
    sorts: []
  }
}
```

Use that payload when the host app creates the generated preference record or when it calls the same host-app path that administrators use for shared presets. The important part is that the record is stored as `scope_type: "shared"` and marked `default: true` only when it should win before owner presets exist.

### 2. Give administrators a separate write path

Regular end users should still save personal presets from the bundled editor. Shared, role, and organization presets work better when the host app exposes an explicit admin form, service object, or maintenance script that sets `scope_type` and, when needed, `scope_key`.

A minimal strong-parameters shape looks like this:

```ruby
params.require(:preset).permit(
  :table_key,
  :name,
  :default,
  :scope_type,
  :scope_key,
  settings: {}
)
```

Typical `scope_key` values are stable business identifiers such as role keys (`"admin"`) or organization IDs/slugs (`"tokyo"`). The host app remains responsible for deciding who may create or update each key.

A copyable host-app controller/service split can stay close to the repository's current controller and model contract:

```ruby
class Admin::TablePreferencePresetsController < ApplicationController
  def create
    preset = ScopedPresetUpserter.call(preset_params)

    redirect_to admin_table_preference_presets_path,
                notice: "Preset saved: #{preset.name}"
  end

  def update
    preset = ScopedPresetUpserter.call(preset_params)

    redirect_to admin_table_preference_presets_path,
                notice: "Preset updated: #{preset.name}"
  end

  private

  def preset_params
    params.require(:preset).permit(
      :table_key,
      :name,
      :default,
      :scope_type,
      :scope_key,
      settings: {}
    )
  end
end
```

```ruby
class ScopedPresetUpserter
  def self.call(attrs)
    scope_type = attrs.fetch(:scope_type)
    scope_key = attrs[:scope_key].presence

    preference = RailsTablePreferences::Preference.find_or_initialize_for(
      user: nil,
      table_key: attrs.fetch(:table_key),
      name: attrs[:name].presence || "default",
      scope_type: scope_type,
      scope_key: scope_key
    )

    preference.user = nil
    preference.scope_type = scope_type
    preference.scope_key = scope_key
    preference.settings = RailsTablePreferences::SettingsNormalizer.call(attrs[:settings] || {})
    preference.default_flag = ActiveModel::Type::Boolean.new.cast(attrs[:default])

    if preference.default_flag?
      RailsTablePreferences::Preference.for_scope(preference.scope_type, preference.scope_key)
                                     .where(RailsTablePreferences.configuration.user_foreign_key => nil)
                                     .for_table(preference.table_key)
                                     .where.not(id: preference.id)
                                     .update_all(default_flag: false)
    end

    preference.save!
    preference
  end
end
```

Why this shape works:

- `user: nil` matches the current model/controller contract for shared, role, and organization presets.
- `scope_type` and `scope_key` stay explicit instead of relying on hidden controller state.
- `RailsTablePreferences::SettingsNormalizer.call(...)` keeps admin-created payloads aligned with the same normalized `columns` / `filters` / `sorts` shape used by the bundled JSON API.
- `default_flag` clearing stays per table + scope so only one default wins inside the same scope bucket.

The mounted JSON API rejects non-owner writes. Build protected administration on top of a host-owned service such as the example above, direct model writes, seeds, or maintenance tasks. Keep the stored `scope_type`, `scope_key`, and normalized `settings` consistent while the host app owns authorization and tenant policy.

### 3. Split the regular editor and the admin flow on purpose

| Surface | Who uses it | What it should save |
| --- | --- | --- |
| Bundled editor | Normal end users | Owner presets only |
| Admin form or seed path | Administrators, setup tasks, support scripts | Shared, role, and organization presets |
| Resolver path | Every request | Whatever presets are available from owner + scope context |

A practical rule of thumb is: let users read every available preset, but only let the regular editor write owner presets. Put shared, role, and organization writes behind an app-specific admin flow.

### 4. Keep `scope_context_method` and admin inputs aligned

The `scope_context_method` decides which non-owner presets are available for the current request. If the method returns role keys and an organization identifier, the admin flow should store those same kinds of values in `scope_key`.

A concrete alignment example looks like this:

```ruby
class ApplicationController < ActionController::Base
  private

  def table_preference_scope_context
    {
      roles: current_user.roles.pluck(:key),
      organization: current_organization.slug
    }
  end
end
```

| Use case | `scope_type` | `scope_key` stored by admin flow | Resolver input that makes it available |
| --- | --- | --- | --- |
| Shared baseline for everyone | `shared` | blank | none |
| Operations role preset | `role` | `operations` | `roles: ["operations", ...]` |
| Tokyo organization preset | `organization` | `tokyo-hq` | `organization: "tokyo-hq"` |

That keeps three things consistent:

- the seed/default data you create up front
- the admin UI or service object that edits scoped presets later
- the runtime resolver that decides which scoped presets the current owner can use

If your runtime context returns numeric IDs, UUIDs, or tenant slugs, store that same stable value in `scope_key`. Avoid saving human-facing labels such as `Operations Team` unless the resolver also returns that exact label.

## Authorization boundary

Rails Table Preferences stores and resolves scoped presets. It does not decide who is allowed to create or edit organization-wide presets in your business application.

If an application exposes shared, role, or organization preset management to administrators, it should enforce authorization in the host application or a custom controller layer.