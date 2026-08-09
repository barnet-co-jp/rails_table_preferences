# Rails Table Preferences documentation

This directory contains focused documentation for Rails Table Preferences.

## Start here

### Choose your first path

Use this short map before the full catalog when you are opening the docs for the first time.

- New install or smallest working UI: start with [Quick start](quick_start.md), then use [Install path options](install_paths.md) if the host app uses Vite, skipped copied assets, or demo generator options.
- Japanese business-app orientation: start with [日本語 quick start](quick_start_ja.md), then follow its links to the English source-of-truth guides for detailed steps.
- Browser preview before a real host-app screen: generate the [Demo screen](demo.md), then use [Sandbox Rails app verification](sandbox.md) if you want a clean end-to-end install check.
- Convention-first Active Record table: start with [Resource table adapters](resource_tables.md), then move to the [Production integration checklist](production_integration_checklist.md) for real index-screen owner, route, query, layout, and export checks.
- Existing custom or hand-written table: use [Quick start](quick_start.md) for the minimum editor/table wiring and [Decision guide](decision_guide.md) when choosing helpers, hidden fields, controller params, exports, or customization paths.
- Real host-app screen already wired but failing: use [Production troubleshooting notes](production_troubleshooting.md) before changing implementation, especially for auth redirects, CSRF, owner lookup, stable `table_key`, or preset persistence issues.
- Release or package-readiness review: use [Release checklist](release_checklist.md), [Package verification](package_verification.md), and [Manual QA checklist](manual_qa.md) after the integration path is working.

## Full catalog

- [Quick start](quick_start.md): the shortest path from installation to a working table preference UI.
- [Production integration checklist](production_integration_checklist.md): the short path from a working demo or quick start to a real host-app index screen.
- [Production troubleshooting notes](production_troubleshooting.md): symptom-driven checks for CSRF 422s, auth redirects, owner lookup failures, unstable `table_key` values, duplicate preset names, and saved presets that do not return on real host-app screens.
- [日本語 quick start](quick_start_ja.md): a low-drift Japanese entrypoint for the main installation, editor, preset, filter/sort, export, and QA workflows.
- [Install path options](install_paths.md): choose the smallest generator option set for default `stimulus-rails`, Vite/package entrypoint, skipped copied assets, or demo verification paths.
- [Support matrix](support_matrix.md): Ruby/Rails runtime requirements, representative CI coverage, and host-app verification guidance for newer Rails releases.
- [Resource table adapters](resource_tables.md): infer user-facing columns from Active Record metadata, apply profile overrides, and register host-owned renderer mappings for TreeView or Rails Fields Kit controls.
- [Rails Fields Kit bridge contract](rails_fields_kit_bridge_contract.md): RTP/RFK ownership boundaries for future bridge metadata, dependency policy, and downstream adoption handoff.
- [Resource table empty messages](resource_table_empty_messages.md): plain text `empty_message:` copy for bundled resource table empty states and the boundary with richer custom partials.
- [Resource table editor placement checklist](render_editor_placement_manual_qa.md): focused evidence for `render_editor: false` screens that place the editor in a toolbar, drawer, tab, sidebar, or separate partial.
- [Manual table scroll wrappers](manual_table_scroll_wrappers.md): `table_preferences_table_tag(...)` `scroll_wrapper:` and `wrapper_options:` guidance for hand-written tables that need a dedicated horizontal scroller.
- [Resource table cell hooks](resource_table_cell_hooks.md): stable body-cell data attributes for light host-app styling and the boundary with custom partials.
- [Table data attribute merge boundary](table_data_attributes.md): host app `data-controller` coexistence and gem-owned `data-rails-table-preferences-*` protection rules for rendered tables.
- [Resource table formatter contract](resource_table_formatter_contract.md): formatter arity, nil-return fallback, and host-app responsibility boundaries for profile display/cell/column blocks.
- [Manual column editor metadata](manual_column_editor_metadata.md): `table_preferences_column(..., editor: ...)` metadata for hand-written table columns and the renderer-registry boundary.
- [Virtual column query boundary](virtual_columns_query_boundary.md): practical virtual/computed column examples that keep joins, preloading, filtering, and sorting in host-app code.
- [Decision guide](decision_guide.md): choose the right helper, adapter, or option for common use cases.
- [Scoped presets](scoped_presets.md): owner, shared, role, and organization scoped presets, default resolution, and minimal operating patterns.
- [Preset selector scope labels](preset_selector_scope_labels.md): package entrypoint and copied/base controller scope-label display boundaries for owner and non-owner presets.
- [Preset name save boundary](preset_name_save_boundary.md): selector, preset name input, save, and save-as-new wording boundaries so host-app copy does not imply an in-place rename API.
- [Fixed columns and column groups](fixed_columns_and_groups.md): `fixed:` / `pinned:` columns, sticky CSS hooks, horizontal scroll-container baseline, and `group:` metadata.
- [Column overflow metadata](column_overflow.md): canonical `overflow:` / `default_overflow:` values, compatibility aliases, the boundary with `default_truncate:`, and why overflow mode is host-owned rather than edited in the bundled editor.
- [Resize and auto-fit guidance](resize_auto_fit.md): resize handle root values, double-click auto-fit bounds, and the manual QA focus for dense or horizontally scrolled tables.
- [Export integration](export_integration.md): reuse saved column visibility/order/labels when building CSV, Excel, or report exports in the host app.
- [Accessibility baseline](accessibility.md): what the bundled editor/controller provide and what the host app still owns.
- [Package status state hook](status_state_hook.md): status-state values, package-entrypoint-only boundary, and QA quick reference for bundled status region cues.
- [Forced-colors manual QA note](forced_colors_manual_qa.md): focused high-contrast evidence handoff for active filters, sorted headers, resize focus, filter panels, and pinned/fixed cells.
- [Editor entrypoint affordances](editor_entrypoint_affordances.md): package-entrypoint-only column search, row move buttons, dirty-state helper, browser QA handoff, and copied-controller boundary.
- [Dirty-state helper visual evidence](dirty_state_helper_visual_evidence.md): focused desktop, narrow viewport, accessibility, and browser-capable handoff evidence for package-entrypoint dirty-state helper changes.
- [Editor reorder accessibility note](editor_reorder_accessibility.md): package-entrypoint visual-only row drag handle, keyboard reorder controls, and copied-controller boundary.
- [Header drag reorder](header_drag_reorder.md): package-entrypoint table-header drag reorder, `draggable: false` opt-out, and host-app interactive header boundary.
- [Bundled editor i18n keys](editor_i18n.md): preset/action/reset/filter/sort/scope/status locale keys and the boundary between locale overrides, controller-root values, copied ERB, and copied JavaScript.
- [Editor root HTML options](editor_root_options.md): add host-app root `id`, class, generic `data-*`, and `aria-*` attributes without copying the bundled editor partial.
- [Non-goals and deferred directions](non_goals.md): intentionally deferred areas such as query builder behavior, CSV/Excel generation, full admin UI, heavy browser tests, and complex sticky layouts.
- [Visual overview](visual_overview.md): representative screen illustrations for the editor, shared/scoped preset orientation, generated demo owner/scope cues, export preview, filter/sort state, and pinned-column table layout.
- [Demo screen generator](demo.md): `--with-demo` and `--with-demo-route` generator options for copying a lightweight browser verification screen into a host app.
- [Demo preview evidence copying](demo_preview_evidence.md): hidden fields and export payload preview copy controls, Clipboard API fallback, and manual selection evidence boundaries for generated demo review notes.
- [Sandbox Rails app verification](sandbox.md): minimal Rails app setup for end-to-end verification before real app integration.
- [Practical examples](examples.md): realistic list-screen integrations for existing `search(params)` / `order_by(params[:sort])` controllers and Ransack controllers.
- [Helper-free controller root URLs](helper_free_controller_root_urls.md): collection/member URL ownership when an existing table partial mounts `data-controller="rails-table-preferences"` manually.
- [Helper-free table root manual QA](helper_free_table_manual_qa.md): focused table-root and wrapper-root smoke checklist for host-app-owned table markup using the bundled controller DOM contract.
- [Troubleshooting](troubleshooting.md): common installation, Stimulus, CSS, API, filter/sort, scoped preset, legacy import, and customization issues.
- [Select filter troubleshooting](select_filter_troubleshooting.md): `values_param`, scalar or label/value select options, option-search threshold cues, and host-app query ownership when select filters do not affect results.
- [Select filter option search threshold](select_filter_option_search_threshold.md): package-entrypoint-only threshold controls for static select option search, empty-result feedback, and the host-owned boundary for remote or async option search.
- [Datetime and time filter browser attributes](datetime_time_filter_attributes.md): package-entrypoint native datetime/time inputs, `min` / `max` / `step` metadata, and host-owned validation/query boundaries.
- [Filter panel viewport boundary](filter_panel_viewport_boundary.md): QA and design handoff note for the current package-entrypoint body-mounted filter panel, bottom-edge internal scrolling boundary, and browser-capable evidence expectations.
- [Manual QA checklist](manual_qa.md): browser and host application checks to run before asking real users to try the feature.
- [Manual QA PR smoke matrix](manual_qa_pr_smoke_matrix.md): PR-scoped quick smoke guidance for docs-only, UI, helper, generator, export, layout, and scoped preset changes.
- [Hidden fields pagination evidence](hidden_fields_pagination_evidence.md): focused evidence guidance for old `page` params when saved filter/sort hidden fields roundtrip through existing search forms.
- [Release checklist](release_checklist.md): packaging, generator, CI, documentation, and sandbox checks before tagging or publishing a release.
- [Package verification](package_verification.md): build and inspect the gem package before tagging or publishing a release.
- [Mounted JSON API](json_api.md): owner preset endpoints, request/response payloads, and the boundary with non-owner scoped preset administration.
- [Controller integration](controller_integration.md): how to resolve saved preferences, fallback settings, and filter/sort params for existing Rails controllers.
- [Filter metadata](filter_metadata.md): how to declare filterable/sortable columns and how neutral filter/sort settings are stored.
- [Filter adapters](filter_adapters.md): adapter strategy for Ransack, Datagrid, Filterrific, and host application search objects.
- [JavaScript entrypoints](javascript_entrypoints.md): Stimulus registration paths for default `stimulus-rails`, Vite, `app/frontend`, custom JS bundlers, Turbo reconnect checks, and the JavaScript public-surface source-of-truth role.
- [TypeScript settings snapshot declarations](typescript_settings_snapshots.md): package-root helper types for settings snapshots exposed through package-entrypoint lifecycle events.
- [JavaScript controller notes](javascript_controller.md): responsibilities, event boundaries, and safety invariants for the bundled Stimulus controller.

## Public surface source-of-truth family

Rails Table Preferences keeps the first public-surface source of truth in the existing docs and package verification family rather than a dedicated manifest file.

- JavaScript package imports, TypeScript snapshot helper types, and the copied-controller boundary are defined in [JavaScript entrypoints](javascript_entrypoints.md) and [TypeScript settings snapshot declarations](typescript_settings_snapshots.md), then checked by package metadata, entrypoint smoke specs, JavaScript syntax checks, and package verification.
- Helper options, rendered table/editor responsibilities, filter/sort metadata, scoped presets, export payloads, and resource-table adapters are defined in the focused guides linked above instead of being mirrored into README.
- Cross-gem Rails Fields Kit bridge ownership is documented in [Rails Fields Kit bridge contract](rails_fields_kit_bridge_contract.md) and kept separate from runtime dependency or adapter implementation decisions.
- Generator options, copied assets, package contents, and release evidence are guarded by [Install path options](install_paths.md), [Release checklist](release_checklist.md), and [Package verification](package_verification.md).
- README remains the newcomer-facing entry point. This docs index remains the detailed map. Package verification decides which docs and runtime files must ship in the gem.

Do not add a TreeView-style public API manifest as the default first response to drift. Consider one only when a surface becomes too large for the focused guide plus package/spec checks to keep clear, such as a growing helper option inventory, many lifecycle event detail keys, or additional package-root JavaScript exports.

## Maintainer entry

- [Product Profile](https://github.com/barnet-co-jp/rails_table_preferences/blob/main/Product%20Profile.md): concise maintainer-facing overview of the product surface, responsibility boundary, and release posture.
- [AGENTS.md](https://github.com/barnet-co-jp/rails_table_preferences/blob/main/AGENTS.md): repository guardrails, source-of-truth order, and change boundaries for assisted maintenance work.
- [CHANGELOG.md](../CHANGELOG.md): current unreleased scope and release narrative.

## Recommended integration order

Use this as a navigation map after choosing a starting path above. The first group gets a new reader to a working screen; later groups are follow-up checks for table behavior, data flow, and release readiness.

### First working screen

1. Install the gem and run the generated migration.
2. Use the production integration checklist when moving from the quick start or demo screen to a real host-app index screen.
3. Mount the engine if you use the bundled JSON API.
4. Confirm the Stimulus controller registration path for the host app. Use the default manifest for `stimulus-rails`, or the package entrypoint for Vite / `app/frontend` apps.
5. For convention-first tables, try `resource_table_for @records` and review [Resource table adapters](resource_tables.md).
6. For manually controlled tables, define table columns with `table_preferences_column`.
7. Render `table_preferences_editor` and `table_preferences_table_tag`.
8. Optionally generate the demo screen with `--with-demo`, or `--with-demo-route` when the route should be added at the same time, after confirming the configured current-owner method returns a persisted owner record.

### Adapt the table surface

1. If the inferred resource table only needs short empty-state copy, use [Resource table empty messages](resource_table_empty_messages.md) before copying the default partial for richer markup.
2. If the inferred resource table only needs light cell styling, use [Resource table cell hooks](resource_table_cell_hooks.md) before copying the default partial.
3. If the inferred resource table should render filter inputs or cell editors through a form-helper library, use the renderer registry context examples from [Resource table adapters](resource_tables.md) before copying a custom partial.
4. If that form-helper library is Rails Fields Kit, review the [Rails Fields Kit bridge contract](rails_fields_kit_bridge_contract.md) to keep RTP metadata ownership, RFK rendering ownership, and host-app query/authorization responsibilities separate before planning adapter work.
5. If a hand-written table column needs cell editor metadata, use [Manual column editor metadata](manual_column_editor_metadata.md) to keep renderer lookup separate from host-owned form submission and persistence.
6. When a hand-written table needs a dedicated horizontal scroller, use [Manual table scroll wrappers](manual_table_scroll_wrappers.md) to keep table attributes and wrapper attributes separate.
7. Use `html_options:` from [Editor root HTML options](editor_root_options.md) when the bundled editor root needs host-app placement attributes without copying the partial.
8. When `render_editor: false` moves a resource table editor into a toolbar, drawer, tab, sidebar, or separate partial, use the [Resource table editor placement checklist](render_editor_placement_manual_qa.md) to record placement evidence without changing the helper contract.
9. For helper-free or host-app-owned table markup, use [Helper-free table root manual QA](helper_free_table_manual_qa.md) after checking the minimal DOM contract in [JavaScript controller notes](javascript_controller.md#minimal-dom-contract-for-helper-free-tables).
10. Add `filter:` and `sortable: true` metadata where needed.
11. For static select filters with longer option lists, review the [Select filter option search threshold](select_filter_option_search_threshold.md) before changing root values or treating option search as a remote/async search feature.
12. For datetime or time filter metadata, use [Datetime and time filter browser attributes](datetime_time_filter_attributes.md) to check native input attributes without moving validation or query semantics out of the host app.
13. Use [Filter panel viewport boundary](filter_panel_viewport_boundary.md) when reviewing package-entrypoint bottom-edge panel behavior or deciding whether future panel changes need browser-capable evidence.
14. Choose `overflow:` / `default_overflow:` values when text should ellipsize, clip, wrap, or stay single-line.
15. Tune [resize and auto-fit root values](resize_auto_fit.md) only when dense headers, custom scroll containers, or host-app CSS make the defaults hard to use.
16. Use `fixed:` / `pinned:` and `group:` metadata only when the table needs fixed columns or grouped headers/exports.
17. Use the decision guide when choosing between controller params, hidden fields, Ransack, ignored columns, scoped presets, exports, and customization options.
18. Review the accessibility baseline for screens with custom styling or stricter keyboard requirements.
19. When forced-colors or high-contrast evidence is needed, use the forced-colors manual QA note to keep browser-capable checks scoped to the relevant states.
20. Review [Bundled editor i18n keys](editor_i18n.md) before copying ERB or JavaScript for wording-only changes.
21. Review non-goals before adding behavior that looks like a query builder, export generator, admin framework, heavy browser test stack, or complex sticky layout engine.

### Wire data, presets, and exports

1. Configure `scope_context_method` only if shared, role, or organization presets are needed.
2. Use `rails_table_preference_params` or `rails_table_preference_merged_params` in controllers.
3. Use `rails_table_preference_export_payload` when CSV/Excel/report exports should follow saved column settings.
4. Use `table_preferences_hidden_fields` when saved filter/sort params should be submitted through an existing search form.
5. For package-entrypoint lifecycle event listeners, use [TypeScript settings snapshot declarations](typescript_settings_snapshots.md) when the host app wants compile-time helpers for `event.detail.settings`.
6. Review [Hidden fields pagination evidence](hidden_fields_pagination_evidence.md) when the existing search form can also submit an old `page` param.

### Verify before release or user handoff

1. Verify the feature in a sandbox Rails app.
2. Review [Support matrix](support_matrix.md) when the host app's Ruby/Rails version is outside the currently documented representative CI matrix.
3. Run the manual QA checklist before asking real users to try the feature.
4. Use the forced-colors manual QA note when the handoff needs high-contrast evidence for active filters, sorted headers, resize handles, filter panels, or pinned/fixed cells.
5. Before release, run the release checklist and package verification guide.

## Responsibility boundary

Rails Table Preferences owns:

- table display preference UI
- column visibility, order, width, and truncation settings
- fixed/pinned column metadata and CSS hooks
- column group metadata
- owner, shared, role, and organization scoped presets
- saved presets and default presets
- filter/sort UI state
- adapter params for host applications or search gems
- resource table column inference and profile overrides when the helper path is used
- resource table body-cell metadata hooks for light host-app styling
- renderer registry lookup for filter/editor metadata when a host app registers renderers
- export column payloads derived from saved display preferences
- baseline accessibility hooks for generated controls

Host applications own:

- actual database search execution
- authorization
- joins and association logic
- business-specific query behavior
- semantic page/table structure around the generated controls
- sticky column offset and scroll-container polish for complex layouts
- grouped table header markup
- cell styling rules, badges, and complex custom table presentation
- renderer registrations and concrete form-helper HTML for filter/editor metadata
- CSV, Excel, and report file generation
- administration UI for shared, role, or organization presets
- final styling and UI polish
