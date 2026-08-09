# Product Profile

## Summary

Rails Table Preferences is a Rails engine/gem for business-style Rails applications with dense index tables. It lets a host application save and restore table display preferences such as visible columns, column order, column width, overflow behavior, fixed columns, column groups, filter UI state, sort UI state, and named presets.

The gem is intentionally integration-friendly rather than all-encompassing. It helps a host application carry display preferences through existing tables, search forms, controller params, convention-first resource table helpers, and export flows without taking over the application's business queries or administrative workflows.

## Intended users

Primary users are maintainers of Rails applications who need configurable table UX for operators, back-office teams, or other users working with large list screens.

Typical adopters need:

- owner-specific display preferences
- optional shared, role, or organization scoped presets
- compatibility with existing search and sort flows
- convention-first table rendering from Active Record metadata with small profile overrides
- copyable customization paths for ERB, CSS, JavaScript, and locales

## Core capabilities

Current repository scope includes:

- table column definitions with labels, visibility, order, width, overflow/truncation, fixed/pinned metadata, groups, filters, sorts, and ignored columns
- resource table helpers that infer Active Record columns, apply table profile overrides, expose stable body-cell metadata hooks, and optionally connect TreeView-style tree tables
- table data attribute merge rules that let host apps add their own controllers while preserving gem-owned table preference bindings
- renderer registries that let host apps map filter/editor metadata to helper libraries such as Rails Fields Kit without making this gem depend on those libraries
- editor and table helpers for rendering a configurable table-preference UI, including root HTML option pass-through for host-app placement attributes
- owner/shared/role/organization preset persistence and default resolution
- controller helpers for merging saved filter/sort state into host-app params
- export payload helpers for CSV/Excel/report code implemented by the host app
- a bundled Stimulus controller, package entrypoint, lightweight TypeScript helper declarations, and lightweight JSON API
- install/demo/customization generators and focused operational documentation

## Responsibility boundary

Rails Table Preferences owns:

- table display preference persistence and editing
- saved filter/sort UI state as UI metadata
- column/preset metadata and helper/controller integration
- Active Record column inference, table profile override application, and renderer registry lookup for resource table helpers
- body-cell data attributes, editor root HTML option merging, and table preference data-attribute protection for generated helper surfaces
- baseline accessibility hooks and lightweight demo/sandbox guidance

Host applications own:

- actual search/query execution
- authorization and tenant/business rules
- grouped header markup and advanced scroll/sticky layout polish
- CSS and manual QA for dense headers, horizontal scroll containers, and resize/auto-fit usability in the final screen
- CSV, Excel, or report file generation
- resource table partial layout, route URLs, and behavior behind rendered filter/editor controls
- full administrative management UI for non-owner presets
- final application design and workflow-specific UX

## Integration posture

The project favors practical Rails integration over framework lock-in.

Maintainers should expect to combine the gem with:

- existing `search(params)` / `order_by(params[:sort])` flows
- Ransack or other search adapters when needed
- `resource_table_for` / `tree_resource_table_for` when convention-first Active Record column inference is useful
- table profiles and renderer registrations when a screen needs small column, filter, editor, or display overrides
- host-app export code driven by `rails_table_preference_export_payload`
- host-app customization via copied ERB, CSS, JavaScript, and locale files

## Release posture

The gem is at v1.0.0 and used in production. The public API (helpers, JSON API, generator options, and Stimulus controller interface) is considered stable.

Representative pull-request compatibility coverage is Rails 7.0, Rails 7.1, Rails 7.2, and Rails 8.0, while the development Gemfile tracks Rails 8.0.x. Host applications evaluating newer Rails releases should treat that as additional verification space until the representative compatibility matrix expands.

Repository-level release confidence is expected to come from:

- `bundle exec rspec`
- `node script/check_javascript_syntax.mjs`
- `npm run test:typescript-declarations`
- `node script/check_ci_workflow_permissions.mjs`
- `bundle exec rake build`
- `bundle exec rake package:verify`
- representative pull-request compatibility lanes for Rails 7.0 / 7.1 / 7.2 / 8.0
- sandbox/demo verification
- manual QA and package verification docs

## Non-goals

The project does not aim to become:

- a generic Active Record query builder
- a replacement for Ransack, Datagrid, or Filterrific
- an authorization framework
- a CSV/Excel/report generator
- a complete admin UI framework for shared/role/organization preset management
- a React/Vue component library

## Maintainer references

Start with these files when orienting yourself. This is a representative maintainer map, not a complete docs catalog; use `docs/index.md` as the source of truth for the full guide inventory.

- `README.md`: newcomer-facing overview, documentation entry points, supported versions, and installation basics.
- `docs/index.md`: full documentation hub and recommended integration order.
- `docs/production_integration_checklist.md`: short checklist for moving from a demo or quick start into a real host-app index screen.
- `docs/production_troubleshooting.md`: symptom-driven checks for real host-app screens where save, reload, auth, CSRF, owner lookup, or stable table keys fail after the demo or quick start works.
- `docs/install_paths.md`: generator option paths for default `stimulus-rails`, Vite/package entrypoint, skipped copied assets, and demo verification.
- `docs/javascript_entrypoints.md`: package entrypoint, copied-controller boundary, Vite registration, package metadata, and JavaScript public-surface source-of-truth notes.
- `docs/typescript_settings_snapshots.md`: package-root helper types for lifecycle event settings snapshots and host-app TypeScript listeners.
- `docs/controller_integration.md`: controller helper signatures, preference resolution, params merge patterns, and host-app search responsibility boundaries.
- `docs/filter_metadata.md`: neutral filter/sort metadata, select option value/label handling, and the boundary between saved UI state and query execution.
- `docs/filter_adapters.md`: adapter responsibilities for Ransack, Datagrid, Filterrific, and host application search objects.
- `docs/scoped_presets.md`: owner, shared, role, and organization preset resolution, defaults, and operating patterns.
- `docs/export_integration.md`: export payload helpers and the boundary with host-owned CSV, Excel, or report generation.
- `docs/support_matrix.md`: Ruby/Rails requirements, representative CI coverage, and newer host-app verification guidance.
- `docs/resource_tables.md`: resource table helper scope, profile overrides, renderer registrations, and TreeView/Rails Fields Kit integration boundaries.
- `docs/resource_table_cell_hooks.md`: stable body-cell metadata hooks and the boundary with custom partials.
- `docs/table_data_attributes.md`: host app `data-controller` coexistence and gem-owned table preference binding protection.
- `docs/resource_table_formatter_contract.md`: formatter arity, nil-return fallback, and host-app responsibility boundaries for profile display/cell/column blocks.
- `docs/editor_root_options.md`: host-app root `id`, class, `data-*`, and `aria-*` pass-through without copying the bundled editor partial.
- `docs/resize_auto_fit.md`: resize handle roots, double-click auto-fit bounds, and dense-table manual QA focus.
- `docs/demo.md`: generated demo screen paths and current-owner preparation for lightweight browser verification.
- `docs/sandbox.md`: minimal Rails app verification before real app integration.
- `docs/manual_qa.md`: browser and host application checks before handing the feature to real users.
- `docs/manual_qa_pr_smoke_matrix.md`: PR-scoped focused smoke, review-state handoff, and browser evidence handoff for changes that do not need the full manual QA checklist.
- `docs/release_checklist.md`: release readiness checks across packaging, generators, CI, docs, and sandbox verification.
- `docs/package_verification.md`: build and inspect the gem package before tagging or publishing a release.
- `docs/troubleshooting.md`: common installation, Stimulus, CSS, API, filter/sort, scoped preset, and customization issues.
- `docs/json_api.md`: owner preset endpoints, payloads, and the boundary with non-owner scoped preset administration.
- `AGENTS.md`: repository guardrails, source-of-truth order, and change boundaries for assisted maintenance work.
- `CHANGELOG.md`: current unreleased scope and release narrative.
