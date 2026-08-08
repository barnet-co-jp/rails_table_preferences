# Filter adapters

Rails Table Preferences may provide Excel-like filter UI in a future version, but it should not become a general-purpose query builder.

The preferred boundary is:

- Rails Table Preferences owns filter UI state, saved filter conditions, saved sorts, presets, and normalized params.
- Host applications or existing gems own ActiveRecord query execution, joins, authorization, database-specific behavior, and business rules.

This lets the gem work alongside tools such as Ransack, Datagrid, Filterrific, or a host application's own search objects.

Use this guide when you need adapter-shape examples for neutral filters and sorts. For full list-screen walkthroughs that keep `search(params)` / `order_by(params[:sort])` in the host app, start with [Practical examples](examples.md) and then return here for the Ransack, Datagrid, Filterrific, or custom search-object mapping boundary.

## Neutral filter format

Saved settings should remain gem-neutral:

```json
{
  "columns": [
    {
      "key": "customer_name",
      "visible": true,
      "order": 30,
      "width": 240,
      "truncate": 20
    }
  ],
  "filters": {
    "customer_name": {
      "operator": "contains",
      "value": "山田"
    },
    "status": {
      "operator": "in",
      "values": ["未出荷", "出荷済"]
    },
    "delivery_date": {
      "operator": "between",
      "from": "2026-01-01",
      "to": "2026-01-31"
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

The saved format should not use Ransack predicates, Datagrid filter names, Filterrific scope names, or application-specific SQL concepts directly.

The `sorts` array is ordered neutral state. The bundled table-header UI keeps the default click cycle single-column, and Shift+click or Shift+Enter/Space preserves the other entries while adding, reversing, or clearing the selected column. Adapters should preserve that order when the target search layer accepts multi-sort input or clearly reduce it to the target layer's supported shape.

## Ransack adapter

The initial adapter is a pure params converter. It does not require Ransack as a gem dependency and does not execute searches itself.

```ruby
filters = {
  customer_name: { operator: :contains, value: "山田" },
  status: { operator: :in, values: ["未出荷", "出荷済"] },
  delivery_date: { operator: :between, from: "2026-01-01", to: "2026-01-31" }
}

sorts = [
  { key: :delivery_date, direction: :desc },
  { key: :customer_code, direction: :asc }
]

ransack_params = RailsTablePreferences::Adapters::Ransack.to_params(
  filters: filters,
  sorts: sorts
)

# => {
#   "customer_name_cont" => "山田",
#   "status_in" => ["未出荷", "出荷済"],
#   "delivery_date_gteq" => "2026-01-01",
#   "delivery_date_lteq" => "2026-01-31",
#   "s" => ["delivery_date desc", "customer_code asc"]
# }

@q = Order.ransack(ransack_params)
@orders = @q.result
```

Ransack accepts `s` as an ordered array, so this adapter keeps the neutral `sorts` order after dropping invalid entries and applying any `sort_param:` metadata. Rails Table Preferences still does not decide whether those fields are allowed, joined, or indexed; that belongs in the host application's Ransack allowlist, scopes, and authorization policy.

`between` maps to lower and upper Ransack predicates instead of a single predicate. A `from` value becomes `<field>_gteq`, a `to` value becomes `<field>_lteq`, and blank bounds are omitted. The adapter does not parse dates, apply time zones, or execute the query.

When the displayed column key differs from the Ransack field, pass normalized columns or use `table_preferences_params(adapter: :ransack)`. The adapter reads existing column metadata: `filter: { param: ... }` overrides the filter field before the predicate is appended, and `sort_param:` overrides the sort field. Without those metadata keys, the saved column key is used unchanged.

Passing `columns:` is metadata mapping, not a security allowlist. Unknown saved filter or sort keys are preserved as fallback Ransack params when they use a supported operator and a valid sort direction, even if they are not present in the current column metadata. That keeps saved state and host-owned presets backward compatible; the host application's Ransack allowlist, scopes, and authorization policy remain the final defense for deciding which params can execute.

```ruby
columns = [
  table_preferences_column(
    :customer_id,
    filter: { type: :text, param: :customer_name },
    sort_param: :customer_name
  )
]

settings = {
  filters: { customer_id: { operator: :contains, value: "山田" } },
  sorts: [{ key: :customer_id, direction: :asc }]
}

ransack_params = table_preferences_params(
  settings: settings,
  columns: columns,
  adapter: :ransack
)

# => {
#   "customer_name_cont" => "山田",
#   "s" => ["customer_name asc"]
# }
```

Supported operator mapping:

| Neutral operator | Ransack predicate |
| --- | --- |
| `contains` | `cont` |
| `not_contains` | `not_cont` |
| `equals` | `eq` |
| `not_equals` | `not_eq` |
| `starts_with` | `start` |
| `ends_with` | `end` |
| `in` | `in` |
| `not_in` | `not_in` |
| `gt` | `gt` |
| `gteq` | `gteq` |
| `lt` | `lt` |
| `lteq` | `lteq` |
| `between` | `gteq` for `from`, `lteq` for `to` |
| `blank` | `blank` |
| `present` | `present` |
| `true` | `true` |
| `false` | `false` |

## Datagrid and Filterrific host adapters

Datagrid and Filterrific are not current built-in adapter classes. Treat them as host-application adapter examples unless a future feature explicitly adds gem-owned helpers.

That means Rails Table Preferences can still supply the neutral `filters` and `sorts` payload, but the host application should translate that payload into the Datagrid or Filterrific API it already trusts.

A small host-owned adapter can live near the controller, query object, or table profile:

```ruby
class OrderDatagridParams
  def self.call(filters:, sorts: [])
    {
      customer_name: filters.dig("customer_name", "value"),
      statuses: filters.dig("status", "values"),
      order: sorts.map { |sort| "#{sort["key"]} #{sort["direction"]}" }
    }.compact
  end
end

settings = rails_table_preference_settings(table_key: :orders)
filters = settings.fetch("filters", {})
sorts = settings.fetch("sorts", [])

grid = OrdersGrid.new(OrderDatagridParams.call(filters: filters, sorts: sorts))
```

This example preserves the neutral sort order because the host-owned Datagrid mapping chooses to pass an ordered list. If the target object only supports a single sort field, reduce the array deliberately and document that project-local choice next to the adapter.

For Filterrific, keep the same boundary: map only the neutral UI state into existing allowed params or scopes, then let the host app apply its normal authorization and query rules.

```ruby
class OrderFilterrificParams
  def self.call(filters:, sorts: [])
    first_sort = sorts.first

    {
      search_query: filters.dig("customer_name", "value"),
      with_status: filters.dig("status", "values"),
      sorted_by: first_sort && "#{first_sort["key"]}_#{first_sort["direction"]}"
    }.compact
  end
end

filterrific = initialize_filterrific(
  Order,
  OrderFilterrificParams.call(filters: filters, sorts: sorts),
  persistence_id: false
)
```

The Filterrific example intentionally consumes only `sorts.first` because many Filterrific setups expose one `sorted_by` scope at a time. If a host app has a multi-sort Filterrific convention, keep that translation in the host-owned adapter and leave the saved Rails Table Preferences shape neutral.

Keep the adapter intentionally boring:

- map only fields the current screen already allows
- reject or ignore unknown keys instead of inferring joins
- keep authorization and business scopes in the host app
- keep Datagrid classes, Filterrific configurations, and custom search objects owned by the host app
- add a project-local adapter first when the mapping is application-specific

## Non-goals

Rails Table Preferences should not become:

- a generic ActiveRecord query builder
- a Ransack replacement
- a Datagrid replacement
- a Filterrific replacement
- a DataTables replacement
- an automatic join inference system
- an authorization system

The gem's role is to provide a good table preference UX and normalized saved UI state that can be handed to existing search layers.
