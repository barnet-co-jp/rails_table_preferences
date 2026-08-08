# Filter metadata

Rails Table Preferences can carry filter and sort metadata without taking responsibility for executing database searches.

This document describes the neutral metadata that can be attached to column definitions and saved settings. Search execution should remain in the host application or in a search gem such as Ransack, Datagrid, or Filterrific.

## Column metadata

Columns can declare filter metadata, sortability, and display metadata such as overflow behavior:

```ruby
columns = [
  table_preferences_column(
    :customer_name,
    label: "得意先名",
    filter: { type: :text, operators: %i[contains equals blank] },
    sortable: true,
    overflow: :ellipsis
  ),
  table_preferences_column(
    :status,
    label: "状態",
    filter: { type: :select, options: ["未出荷", "出荷済", "保留"] },
    sortable: true
  ),
  table_preferences_column(
    :delivery_date,
    label: "納品日",
    filter: { type: :date, operators: %i[equals gteq lteq between] },
    sortable: true
  ),
  table_preferences_column(
    :shipped_at,
    label: "出荷日時",
    filter: { type: :datetime },
    sortable: true
  ),
  table_preferences_column(
    :dispatch_time,
    label: "出荷時刻",
    filter: { type: :time },
    sortable: true
  ),
  table_preferences_column(
    :note,
    label: "備考",
    filter: true,
    overflow: :wrap
  )
]
```

You can also omit `label:` when the label is resolved through `i18n_key:` or a database column comment via `model:`.

Shorthands are available:

```ruby
table_preferences_column(:customer_name, label: "得意先名", filter: true)                         # { "type" => "text" }
table_preferences_column(:status, label: "状態", filter: :select)                                 # { "type" => "select" }
table_preferences_column(:customer_name, label: "得意先名", overflow: :truncate)                   # overflow: "ellipsis"
table_preferences_column(:internal_note, label: "内部メモ", filter: false, overflow: :wrap)        # no filter metadata, wrapped text
```

The metadata is serialized into `columns_json` so the front-end can decide which filter UI to render and how to apply static display behavior such as overflow. It is not a query definition.

For `select` filters, `options:` accepts scalar values or label/value hashes. Scalar options keep the historical behavior: the same value is used for the HTML `<option value>`, visible option text, saved filter value, and adapter params.

Use `{ value:, label: }` when the saved/search value should be stable machine data and the UI should show a human label:

```ruby
table_preferences_column(
  :status,
  label: "状態",
  filter: {
    type: :select,
    values_param: :statuses,
    options: [
      { value: "pending", label: "未出荷" },
      { value: "shipped", label: "出荷済" },
      { value: "hold", label: "保留" }
    ]
  }
)
```

The package entrypoint controller renders the label as option text, stores the `value` in saved filter settings, restores multi-select selected state by `value`, and passes that `value` through the ControllerParams / Ransack adapters. The copied/base controller path currently keeps scalar select option rendering as its safe default; host apps that copy and maintain that controller should use scalar options unless they have ported the package entrypoint label/value normalization. The package entrypoint also uses the label in the filter button active summary when it can resolve a saved value to a known option; unknown or stale saved values fall back to the raw value so the summary stays readable. It does not infer labels from enums, load remote options, or change host-app query execution.

For long static option lists, the package entrypoint controller can show an in-panel option search when the option count reaches the configured threshold. See [Select filter option search threshold](select_filter_option_search_threshold.md) for the root value, no-results cue, and package-entrypoint-only boundary.

For bundled single-value `text`, `number`, and `date` filters, `placeholder:` is rendered as the browser `placeholder` attribute on the generated value input:

```ruby
table_preferences_column(
  :order_number,
  label: "注文番号",
  filter: { type: :text, placeholder: "例: ORD-1001" }
)
```

For the `between` operator, use separate `from_placeholder:` and `to_placeholder:` metadata so the lower and upper bound inputs can show different examples:

```ruby
table_preferences_column(
  :delivery_date,
  label: "納品日",
  filter: {
    type: :date,
    operators: %i[between],
    from_placeholder: "2026-01-01",
    to_placeholder: "2026-01-31"
  }
)
```

Placeholder values are escaped before they are written to the generated input attributes. They are only browser affordances; they do not change saved filter settings, controller params adapter output, validation, query execution, or filter summaries. Select filter prompts, visible hint text, and validation messages remain outside the bundled controller contract for this slice.

For `number` and `date` filters that also need browser `min`, `max`, or `step` affordances, see [Filter input attributes](filter_input_attributes.md). Keep that guide as the companion reference for package-entrypoint input attributes rather than repeating the same browser-affordance boundary in this metadata overview.

## Richer widget rendering

The bundled filter panel intentionally renders simple browser controls from neutral metadata. If a screen needs a date picker, autocomplete, Select2-style select, Rails Fields Kit helper, or another form-helper widget, keep that widget as host-app-owned HTML instead of treating the bundled filter panel as the widget dependency owner.

Use the renderer registry path as the first slice when the host app can keep the table partial shape and only swap the concrete control for one filter family. In that path, Rails Table Preferences carries the column key, filter metadata, saved filter state, and adapter params; the registered renderer owns the HTML for that one widget family. Use a custom partial instead when the screen needs a different header layout, grouped controls, surrounding help text, or other markup that is bigger than a metadata-to-helper mapping.

A useful split is:

- Rails Table Preferences owns the column key, filter metadata, saved filter state, and adapter params.
- A custom partial or renderer registry mapping owns the concrete widget HTML.
- The host app or external helper owns widget initialization, validation display, remote option loading, accepted query params, and authorization.

For the first copyable renderer registry path, see the [Rails Fields Kit end-to-end example](resource_tables.md#rails-fields-kit-end-to-end-example). It shows Rails Table Preferences carrying metadata and saved state while the host app registers concrete `rfk_*` rendering behavior. Do not add a widget JavaScript package or form-helper gem dependency to Rails Table Preferences just to render one screen's richer filter input.

This means richer filter widgets are current host-app integration guidance, not a promise that the bundled controller will gain autocomplete, async option loading, dependent selects, or third-party widget initialization. Keep remote endpoints, query execution, authorization, validation copy, retry UI, selected-option preload policy, and widget lifecycle policy in the host app or the helper library that renders the widget.

## Bundled default filter operators

When `operators:` is omitted, the bundled controller chooses a default operator list from the filter type. `filter: true` and `filter: { type: :text }` both use the default text row.

| Filter type | Default operators |
| --- | --- |
| `text` / default | `contains`, `equals`, `starts_with`, `ends_with`, `blank`, `present` |
| `number` | `equals`, `gteq`, `lteq`, `gt`, `lt`, `blank`, `present` |
| `date` | `equals`, `gteq`, `lteq`, `between`, `blank`, `present` |
| `datetime` / `datetime-local` | `equals`, `gteq`, `lteq`, `between`, `blank`, `present` |
| `time` | `equals`, `gteq`, `lteq`, `between`, `blank`, `present` |
| `select` | `in`, `not_in`, `blank`, `present` |
| `boolean` | `true`, `false`, `blank`, `present` |

Passing `operators:` replaces the default list instead of appending to it. The order in the array is the order shown in the bundled filter panel, so use a short explicit list when the host app search layer only supports a subset of predicates.

The bundled controller maps `datetime` and `datetime-local` to a native `datetime-local` input, and maps `time` to a native `time` input. Their saved values remain the browser input strings in the same neutral `value` / `from` / `to` shape used by `date`. Rails Table Preferences does not normalize time zones, convert browser-local datetimes, or build database queries; the host application must interpret those strings in its own timezone and search layer.

The bundled controller has labels for additional operators such as `not_contains` and `not_equals`, but those operators are not included in the default text set. Host apps may opt in by passing them through `operators:`, but Rails Table Preferences still only saves neutral filter state and shapes adapter params. Query execution, unsupported predicate handling, joins, and authorization remain the responsibility of the host application or search adapter.

If the host app only needs to change bundled filter/sort wording such as `絞り込み`, `条件`, `開始`, `終了`, or sort labels, treat that as a copy-override concern rather than metadata design. See [Accessibility baseline](accessibility.md) and [JavaScript controller notes](javascript_controller.md).

Supported overflow values are:

- `:ellipsis` or `:truncate`: single-line hidden overflow with `...`
- `:clip`: single-line hidden overflow without `...`
- `:wrap`: multi-line wrapping
- `:nowrap`: single-line overflow without clipping

## Sort UI

When `sortable: true` is set, the default Stimulus controller lets users click the table header to cycle through sort states:

1. no sort -> ascending
2. ascending -> descending
3. descending -> clear sort

The current sort state is saved in the neutral `sorts` array:

```json
{
  "sorts": [
    {
      "key": "delivery_date",
      "direction": "desc"
    }
  ]
}
```

A normal header click replaces `sorts` with the clicked column, preserving the compact single-column cycle. Hold Shift while clicking a header, or while pressing Enter or Space on a focused header, to preserve other sort entries and add, reverse, or clear that column as a secondary sort. Array order is the sort priority.

For example, Shift-activating `customer_code` while `delivery_date` is already sorted produces:

```json
{
  "sorts": [
    { "key": "delivery_date", "direction": "desc" },
    { "key": "customer_code", "direction": "asc" }
  ]
}
```

Rails Table Preferences carries and adapts the ordered neutral array. The first entry is the primary sort; later entries are secondary sorts in priority order. Use [Filter adapters](filter_adapters.md) to check whether a target adapter preserves every sort entry, such as Ransack, or deliberately reduces the array to a single sort for existing controller compatibility.

The primary sorted header receives `aria-sort`. Every sorted header receives an `aria-description` with its one-based priority and a minimal visual indicator:

- ascending: `▲`
- descending: `▼`
- none: no indicator

The sort click handler ignores clicks from filter buttons, resize handles, buttons, inputs, selects, and textareas so it does not interfere with filtering, resizing, or other controls. Double-clicking a resize handle auto-fits column width and stores the result as normal width state; it does not change filter or sort state.

## Mapping to existing controller params

Many Rails applications already expose list screens through methods such as:

```ruby
@warehouse_stocks = WarehouseStock
  .search(params)
  .order_by(params[:sort])
```

For these applications, add plain param names to the column metadata:

```ruby
columns = [
  table_preferences_column(
    :customer_name,
    label: "得意先名",
    filter: { type: :text, param: :search_word },
    overflow: :ellipsis
  ),
  table_preferences_column(
    :status,
    label: "状態",
    filter: { type: :select, values_param: :statuses, options: [
      { value: "pending", label: "未出荷" },
      { value: "shipped", label: "出荷済" }
    ] }
  ),
  table_preferences_column(
    :delivery_date,
    label: "納品日",
    filter: { type: :date, from_param: :from_date, to_param: :to_date },
    sortable: true
  ),
  table_preferences_column(
    :shipped_at,
    label: "出荷日時",
    filter: { type: :datetime, from_param: :from_shipped_at, to_param: :to_shipped_at },
    sortable: true
  )
]
```

Supported plain-param metadata:

| Metadata key | Purpose |
| --- | --- |
| `param` | Scalar filter param name |
| `values_param` | Multi-value filter param name |
| `from_param` | Lower-bound/range start param name |
| `to_param` | Upper-bound/range end param name |
| `operator_param` | Optional param that receives the selected operator |
| `sort_param` | Sort key name passed as the sort value |

`operator_param` is not emitted for every operator. The ControllerParams adapter currently maps operators as follows:

- `between` writes the `from` and `to` values to `from_param` / `to_param`, or to the `from_<param>` / `to_<param>` fallbacks. It does not emit `operator_param`.
- `gteq` and `gt` write the scalar value to `from_param`, or to the `from_<param>` fallback. They do not emit `operator_param`.
- `lteq` and `lt` write the scalar value to `to_param`, or to the `to_<param>` fallback. They do not emit `operator_param`.
- `in` and `not_in` write an array to `values_param`, or to the base `param` fallback. They do not emit `operator_param`.
- `blank`, `present`, `true`, and `false` emit the operator as the signal because they do not carry a separate value. They use `operator_param` when provided, otherwise `<param>_operator`.
- Other scalar operators such as `contains` and `equals` write the scalar value to `param`. They also emit `operator_param` only when that metadata key is present.

If an existing `search(params)` implementation expects an operator name for every condition, normalize that expectation in host-app code or provide metadata/UI conventions that match the adapter output. Rails Table Preferences keeps this adapter as a params-shaping helper; it does not execute the query or infer a host application's predicate semantics.

The plain ControllerParams adapter emits one top-level sort value for compatibility with common `order_by(params[:sort])` style controllers. If `settings["sorts"]` contains multiple entries, it uses the first valid entry after metadata mapping and ignores the rest. Use `sort_param:` to change the top-level sort param name:

```ruby
RailsTablePreferences::Adapters::ControllerParams.to_params(
  filters: settings["filters"],
  sorts: settings["sorts"],
  columns: columns,
  sort_param: :order
)
```

## Saved filter settings

Saved filter conditions use a neutral format:

```json
{
  "filters": {
    "customer_name": {
      "operator": "contains",
      "value": "山田"
    },
    "status": {
      "operator": "in",
      "values": ["pending", "shipped"]
    },
    "delivery_date": {
      "operator": "between",
      "from": "2026-01-01",
      "to": "2026-01-31"
    },
    "shipped_at": {
      "operator": "between",
      "from": "2026-01-01T09:00",
      "to": "2026-01-01T18:00"
    },
    "dispatch_time": {
      "operator": "gteq",
      "value": "09:30"
    }
  },
  "sorts": [
    {
      "key": "delivery_date",
      "direction": "desc"
    },
    {
      "key": "customer_code",
      "direction": "asc"
    }
  ]
}
```

The saved `sorts` array keeps the order written by the bundled controller, an import, or a host-app custom/copied controller. The bundled controller writes at most one entry, while custom controllers can write multiple entries when the host app owns the multi-sort interaction.

`datetime` / `datetime-local` and `time` filters do not change the saved condition shape. The values above are strings from the browser input and are passed through adapters without timezone normalization. Convert them to the host application's timezone-aware query representation before executing database searches.

`SettingsNormalizer` normalizes:

- symbol keys to string keys
- filter entries with blank keys are ignored before condition normalization
- `predicate` to `operator`
- scalar `values` to arrays
- sort aliases `column`/`dir` to `key`/`direction`
- sort direction casing to `asc` or `desc`

Invalid filters with blank keys or without an operator are dropped. Invalid sorts without a key, without a direction, or with a direction other than `asc` or `desc` are dropped.

## Ignored columns

When `ignored_columns`, per-column `ignored: true`, or unresolved labels are used, saved filters and sorts for those columns are also removed from `settings_json`.

This prevents hidden columns from being reintroduced through an old saved preference.

## Search adapters

The neutral format can be converted for an existing search layer.

### ControllerParams adapter

Use this adapter for existing controllers that accept plain params:

```ruby
preference = current_user.table_preferences.find_by!(table_key: "warehouse_stocks", name: "default")
settings = preference.settings

preference_params = RailsTablePreferences::Adapters::ControllerParams.to_params(
  filters: settings["filters"],
  sorts: settings["sorts"],
  columns: columns
)

merged_params = params.to_unsafe_h.merge(preference_params)

@warehouse_stocks = WarehouseStock
  .search(merged_params)
  .order_by(merged_params["sort"])
```

Example output:

```ruby
{
  "search_word" => "山田",
  "statuses" => ["pending", "shipped"],
  "from_date" => "2026-01-01",
  "to_date" => "2026-01-31",
  "sort" => "-delivery_date"
}
```

Descending sorts are prefixed with `-` by default. Ascending sorts use the key as-is. If multiple neutral sort entries are present, this adapter emits only the first valid mapped sort because the plain controller shape has a single sort slot. Use `sort_param:` to change the top-level sort param name:

```ruby
RailsTablePreferences::Adapters::ControllerParams.to_params(
  filters: settings["filters"],
  sorts: settings["sorts"],
  columns: columns,
  sort_param: :order
)
```

### Ransack adapter

Use this adapter when the host application already uses Ransack:

```ruby
ransack_params = RailsTablePreferences::Adapters::Ransack.to_params(
  filters: settings["filters"],
  sorts: settings["sorts"]
)

@q = Order.ransack(ransack_params)
@orders = @q.result
```

The Ransack adapter emits `"s"` as an ordered array, so multiple valid neutral sort entries are preserved in the order stored in `settings["sorts"]`. Rails Table Preferences does not execute the query itself. Host applications remain responsible for authorization, joins, allowed searchable fields, and business-specific filtering.
