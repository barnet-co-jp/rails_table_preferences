# Changelog

All notable changes to Rails Table Preferences will be documented in this file.

The format is based on a lightweight Keep a Changelog style, and this project currently follows early pre-1.0 semantic versioning.

## [Unreleased]

Until v0.1.0 is tagged, the detailed entries in this section are the temporary source for the initial release contents. In the release-prep or tag PR, move the landed entries into `[0.1.0] - YYYY-MM-DD`, leave a fresh empty `[Unreleased]` section for post-release work, and keep open pull requests or proposal issues out of the dated release entry until they land.

### Release highlights

- Table preference persistence and preset resolution cover owner, shared, role, and organization scopes for dense business index screens.
- Resource table helpers, column metadata, fixed/pinned columns, column groups, renderer registries, and data-attribute boundaries provide convention-first table integration without taking over host-app presentation.
- Filter, sort, controller params, Ransack, hidden-field, and export payload helpers let host apps reuse saved display state while keeping business queries and file generation in the host app.
- Bundled Stimulus, copied/package entrypoints, install/demo generators, and package verification support both default `stimulus-rails` and custom bundler integration paths.
- Focused user and maintainer documentation now covers quick start, production integration, support, accessibility, demo/sandbox/manual QA, release checks, Product Profile, and assisted-maintenance guardrails.

### Added

- Initial table preference persistence model and Rails engine structure.
- Owner-specific table preference records with configurable owner model and owner foreign key.
- Scoped preset support for owner, shared, role, and organization presets.
- Default preset resolution across owner, role, organization, and shared scopes.
- JSON API for listing, loading, creating, updating, and deleting presets.
- Rails controller helpers for resolving saved settings and converting saved filter/sort state into host app params.
- Rails controller params helpers accept `fallback:` settings so screens can apply default filter/sort params only when no saved preference is resolved.
- Plain controller params adapter for existing `search(params)` / `order_by(params[:sort])` style controllers.
- Ransack params adapter.
- Hidden fields helper for submitting saved filter/sort params through existing search forms.
- Export payload helper for host app CSV, Excel, or report generation.
- Column definition helper with labels, locale lookup, visibility, order, width, truncation, filters, sorting, fixed/pinned metadata, groups, ignored columns, optional `export_key` value-extraction metadata, and manual-column `editor:` metadata for renderer registry lookup.
- Resource table helpers for convention-first Active Record column inference, table profile overrides, optional tree table rendering, and additive table semantics.
- Resource table helpers can pass table HTML options such as `id`, `class`, `data`, and `aria` through to the rendered table while preserving gem-owned controller data attributes.
- Resource table helpers support opt-in captions through `caption:` and keep the caption contract separate from table HTML options.
- Resource table helpers support `render_editor: false` so host apps can render the generated editor separately while keeping the default editor-plus-table behavior unchanged.
- Table and resource table helpers support an opt-in scroll wrapper so host apps can wrap generated tables in the bundled horizontal scroll container class without changing table semantics.
- Table profiles can add virtual or computed columns, including formatter-backed values that are not inferred from the Active Record model.
- Renderer registries for mapping filter and editor metadata to host-app helper libraries such as Rails Fields Kit.
- Column group helper for host app grouped table headers and grouped export headers.
- Settings normalizer for current and legacy `ColumnAdjustment`-style settings payloads.
- Bundled Stimulus controller for applying column visibility, order, width, truncation, filters, sorts, header drag reorder, resize handles, pinned column hooks, and preset editing behavior.
- Copy-based JavaScript, stylesheet, view, and install generators.
- Optional `--with-demo` install generator mode for local browser verification.
- Optional `--with-demo-route` install generator mode for copying the demo screen and adding its route in one explicit opt-in step.
- Generated demo verification includes owner, role, organization, export payload preview, existing search form hidden fields preview, preview evidence copy controls, fixed/grouped column, async failure recovery, and demo-state reset checks.
- Optional `--skip-javascript` and `--skip-stylesheets` install generator modes.
- Legacy `ColumnAdjustment` import rake task.
- Focused documentation for quick start, Japanese quick start, production integration checklist, install paths, support matrix, resource table adapters, resource table cell hooks, table data attribute merge boundaries, resource table formatter contract, manual column editor metadata, manual table scroll wrappers, decision guide, practical examples, controller integration, filter metadata, filter adapters, scoped presets, fixed columns/groups, column overflow, resize/auto-fit root values, export integration, accessibility baseline, editor i18n, editor root HTML options, visual overview, non-goals, demo, sandbox verification, troubleshooting, select filter troubleshooting, select filter option search threshold, datetime/time filter browser attributes, filter panel viewport boundary, hidden fields pagination evidence, manual QA, manual QA PR smoke matrix, release checklist, package verification, JavaScript entrypoints, TypeScript settings snapshot declarations, JavaScript controller notes, and Turbo reconnect checks.
- TypeScript lifecycle event detail helper declarations for mapping `rails-table-preferences:*` event names to success or error detail shapes from the package root.
- Pull request template guidance for automated verification, manual QA, UI/visual evidence, representative surfaces, focused viewport/state checks, and browser-capture handoff.
- GitHub Actions CI for Ruby specs, JavaScript syntax, TypeScript declaration smoke, CI workflow permission policy, gem build, and package verification, plus representative pull-request Rails compatibility lanes for Rails 7.0, Rails 7.1, Rails 7.2, and Rails 8.0.
- Package entrypoint smoke boundary coverage now guards that generated demo browser smoke remains scoped to copied/base controller behavior while package-entrypoint-only affordances stay in source-level and manual QA boundaries.
- Package verification now guards representative core runtime files used by resource tables, adapters, formatters, registries, and helpers.
- Package verification now checks the packaged `package.json` top-level `types` target and reports it as `package.json#types` when missing.
- TypeScript declaration smoke verifies package-root, `rails_table_preferences/controller`, and representative lifecycle event detail imports under the repository bundler-style resolver.

### Changed

- The initial release target now includes the former v0.2 advanced preference distribution and table layout features.
- README roadmap and current scope were updated to reflect the expanded v0.1 scope.
- Generated migrations use nullable owner references and `scope_type` / `scope_key` to support owner, shared, role, and organization presets.
- The bundled JavaScript controller treats non-owner presets as read-only in the normal editor path and falls back to creating an owner preset when saving edits.
- Preset list loading failure copy now explains the current-name-only fallback and asks users to check the connection and reload before retrying the editor flow.
- The package entrypoint controller now reports Show all columns and Hide all columns bulk actions through the existing editor status region, including the all-hidden recovery path.
- Resource table all-columns-hidden empty state copy now points users to the table preferences editor's Show all columns / 全列表示 recovery action instead of reading like a generic empty table.
- Resource table `except:` filtering now treats a belongs_to foreign key exclusion, such as `customer_id`, as excluding the companion association convenience column too, while association-name exclusions still leave the raw foreign key attribute available.
- Select filter option search copy now separates the label from the placeholder so the field names the action and the placeholder describes searching option names.
- The package entrypoint controller adds a lightweight preset selector search for larger preset collections while keeping the native select, scope grouping, and preset payload semantics unchanged.
- The package entrypoint editor column search now shows a visible/total result count cue for matching queries while keeping no-results queries on the existing empty-search message.
- Saved-preset search no-results copy now describes matches as load candidates so users do not confuse the selector search with the save target or current preset name input.
- The package entrypoint controller now shows a saved-preset search clear button while a preset search query is active, restoring all preset options without calling the saved preset API.
- The package entrypoint preset selector now marks default presets with `（既定）` instead of a bare `*` while preserving scope labels, option order, option values, preset identity data, and save/load/delete behavior.
- Preset selector hint copy now explains the `[shared]` / `[role]` / `[organization]` scope markers and `（既定）` default marker near the selector without changing option resolver behavior.
- The generated demo verification panels now use Japanese sample-screen wording around hidden-field evidence, export payload evidence, owner/scope context, reset, and async-failure checks while preserving the same demo behavior and technical boundary cues.
- The generated demo summary now groups preset scope, sample rows, resize/overflow, and fixed/grouped-header checks into scannable sections while keeping the same demo behavior.
- The package entrypoint filter button active summary now shows `{ value:, label: }` select option labels when a saved value matches a known option, while unknown values still fall back to the raw saved value.
- The package entrypoint editor now exposes a separate dirty-state helper for unsaved changes while leaving async operation messages in the existing status region.
- Datetime and time filters in the package entrypoint render native browser inputs and pass `min`, `max`, and `step` metadata as browser attributes without changing saved filter values or query semantics.
- Column resize drag handling now uses Pointer Events for mouse, touch, pen, and `pointercancel` cleanup while keeping double-click auto-fit on its separate path.
- The Ransack adapter can read normalized column metadata so `filter: { param: ... }` and `sort_param:` override the saved column key before params are handed to the host app.
- The default development Gemfile now pins Rails 8.0.x to match the current representative pull-request compatibility matrix.
- The package verification path now resolves documented package root and controller export targets, then checks their packaged JavaScript relative import/export references.
- Package verification documentation now records `docs/editor_reorder_accessibility.md` as a required packaged docs entrance while keeping `docs/preset_name_save_boundary.md` outside `REQUIRED_PATHS` until it is intentionally promoted.
- Documentation now states the bundled sort UI single-sort boundary and leaves multi-sort composition to host apps.
- Filter adapter documentation now distinguishes ordered neutral `sorts` arrays that Ransack or host-owned adapters can preserve from plain controller params that intentionally reduce to the first valid sort for existing `order_by(params[:sort])` compatibility.
- Documentation now keeps richer filter widgets, date pickers, autocomplete, and external helper widgets as host-app-owned renderer or custom-partial responsibilities instead of bundled filter UI dependencies.
- Export integration documentation now clarifies that spreadsheet formula-like value neutralization belongs to the host app exporter or serializer, not to `export_keys`, `column_keys`, or `headers` metadata.
- Production integration guidance now calls out association preloading when resource table formatters read related records, including quick host-app smoke checks for query logs or existing N+1 guards.
- Resource table formatter docs and specs now make formatter exceptions a host-app formatter responsibility and keep that separate from the default no-formatter fallback.
- Pull request template guidance now has a single canonical `.github/pull_request_template.md` source that keeps manual QA, UI/visual evidence, compatibility, and risk sections together.
- Manual QA documentation now includes a full checklist jump map after the quick smoke path so release sign-off and host-app handoff reviewers can reach each section without changing checklist scope.

### Fixed

- Engine routes accept `table_key` values containing dots without treating the suffix as a response format.
- Generator task loading works when the gem is used from a host Rails app.
- Generated migration index names avoid database identifier length issues.
- Rails 7.0 / Ruby 3.1 pull-request compatibility checks avoid `i18n` 1.15.x because that dependency line requires Fiber storage APIs unavailable on Ruby 3.1.
- Engine route names avoid duplicate route name conflicts in the test app.
- Private `current_user` methods are supported.
- Saved filter/sort state survives editor apply operations.
- TypeScript lifecycle action declarations now include the package-entrypoint clear-filters-and-sorts success action, matching the already documented applied event detail.
- Current column metadata overrides stale saved metadata for labels, filters, sortable state, and pinned state.
- Ignored columns are filtered out of editor payloads and saved settings.
- Boolean `false` filter values are preserved through hidden-field and controller-params round trips while `nil`, empty strings, and blank array items remain omitted.
- Saved column numeric settings now drop non-positive or malformed `width`, `truncate`, and `order` values while preserving positive numeric values and numeric strings.
- The package entrypoint controller restores the preset selector to the applied preset after a failed preset load instead of leaving the failed selection visible.
- Select filter option search no longer shows the no-results message when the current selected option is the only match, while still preserving selected options as visible context for non-matching queries.
- The install generator now rejects custom owner foreign keys that do not end with `_id`, avoiding generated reference migrations and table preference indexes that disagree with the configured owner column.

## [0.1.0] - Unreleased

Initial public release target. The entries above describe the planned contents of this release until it is tagged.
