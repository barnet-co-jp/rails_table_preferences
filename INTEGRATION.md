# Host app integration

Before adding host-app code around Rails Table Preferences, use the public integration surface first.

- Resolve presets outside controllers with `RailsTablePreferences.resolve_preference` / `RailsTablePreferences.resolve_settings` instead of querying `RailsTablePreferences::Preference` directly.
- Use `rails_table_preference_params`, `rails_table_preference_merged_params`, and `rails_table_preference_export_payload` instead of parsing saved settings ad hoc.
- Listen to documented package lifecycle events instead of overriding controller internals only to observe state. Header sort/filter changes are exposed through `rails-table-preferences:state-changed`.
- Treat shipped TypeScript declarations as the package contract. Do not promote undocumented Stimulus controller methods into a host-owned public API declaration unless the host deliberately owns a replacement controller.

See [`docs/host_app_integration_guardrails.md`](docs/host_app_integration_guardrails.md) for the full anti-pattern table, controller-independent resolver examples, lifecycle event actions, and responsibility boundary.
