# Package verification

Use this guide after `bundle exec rake build` to confirm the gem package contains the files a host Rails application needs.

## Build

```bash
bundle exec rake build
```

This should create a `.gem` file under `pkg/`.

## Automated verification

Run the package verification task:

```bash
bundle exec rake package:verify
```

The task checks the newest built gem under `pkg/` and fails if required runtime, generator, asset, task, task dependency, changelog, package metadata, JavaScript entrypoint, packaged declaration, resource table partial, default locale, or documentation files are missing. It also reads the packaged `package.json`, verifies that documented `exports` targets and the top-level `types` target point at files that are present in the same built gem, checks that those JavaScript package targets' relative import/export references resolve to packaged `.js` files, checks that declaration targets' relative import/export references resolve to packaged `.d.ts` files, verifies that the packaged `package.json` remains private resolver metadata (`private: true`, `version: "0.0.0"`), and verifies that gemspec release metadata URLs still point at the expected repository, changelog, and documentation pages.

A successful run prints a message like:

```text
Package verification passed: rails_table_preferences-1.0.0.gem
```

If required files, package export or top-level types targets, package-internal JavaScript imports, package-internal declaration imports, packaged metadata, or gemspec release metadata are missing or invalid, the task prints the missing paths and exits with failure.

Failure output starts with a compact summary line before the detailed lists:

```text
Package verification failed: rails_table_preferences-1.0.0.gem
Package verification summary: 4 issue(s) (required files: 1, package export targets: 1, package internal JavaScript imports: 1, package internal declaration imports: 1, package metadata errors: 0, gemspec metadata errors: 0)
```

Use the summary line in PR bodies, the pull request template's release/package evidence field, release checklist notes, or CI triage comments when you need to share the failure quickly. Then use the detailed lists below it to find the exact missing file, export target, unresolved JavaScript import, unresolved declaration import, package metadata error, or gemspec metadata error. `package metadata errors` cover the packaged `package.json` resolver metadata boundary such as `private: true` and `version: "0.0.0"`; `gemspec metadata errors` cover release metadata URLs such as homepage, source, changelog, and documentation links. The package export targets count also includes the top-level package `types` target when present; detailed output labels it as `package.json#types` so it remains distinct from entries under `exports`. The summary is a human-readable wrapper around the existing verifier result; it does not replace the structured `PackageVerifier.call` hash.

## RubyGems publish boundary

`bundle exec rake package:verify` is a package-content gate, not a RubyGems publish approval. A passing result means the built gem contains the expected files, package metadata, gemspec release metadata, JavaScript export wiring, and declaration re-exports; it does not decide the publishing account, MFA or trusted-publishing posture, checksum/provenance handling, selected artifact, or final release command.

Keep those release-time decisions in the [RubyGems publish boundary checks](release_checklist.md#rubygems-publish-boundary-checks). The release owner should confirm that the `.gem` artifact being published is the same build output that passed package verification, or record why a fresh artifact was built and re-verified.

Do not add repository secrets, change RubyGems settings, create a tag, publish the gem, or introduce release automation from package verification docs work.

## Manual inspection

The automated task is the normal gate. Manual inspection is still useful before tagging a release.

List the packaged files:

```bash
gem contents pkg/rails_table_preferences-*.gem --all
```

Or unpack the gem into a temporary directory:

```bash
rm -rf tmp/package_check
mkdir -p tmp/package_check
gem unpack pkg/rails_table_preferences-*.gem --target tmp/package_check
find tmp/package_check -maxdepth 4 -type f | sort
```

## Required files

The verification task checks that the package includes at least:

```text
app/assets/stylesheets/rails_table_preferences.css
app/controllers/rails_table_preferences/application_controller.rb
app/controllers/rails_table_preferences/preferences_controller.rb
app/controllers/concerns/rails_table_preferences/controller.rb
app/helpers/rails_table_preferences/table_preferences_helper.rb
app/helpers/rails_table_preferences/table_preferences_editor_html_options_helper.rb
app/helpers/rails_table_preferences/column_options_helper.rb
app/javascript/controllers/rails_table_preferences_controller.js
app/javascript/rails_table_preferences/controller.js
app/javascript/rails_table_preferences/controller.d.ts
app/javascript/rails_table_preferences/index.js
app/javascript/rails_table_preferences/index.d.ts
app/views/rails_table_preferences/_editor.html.erb
app/views/rails_table_preferences/_resource_table.html.erb
app/views/rails_table_preferences/_tree_resource_table.html.erb
app/views/rails_table_preferences/_tree_resource_table_row.html.erb
config/routes.rb
config/locales/en.yml
config/locales/ja.yml
lib/generators/rails_table_preferences/install/install_generator.rb
lib/generators/rails_table_preferences/install/templates/create_table_preferences.rb
lib/generators/rails_table_preferences/install/templates/initializer.rb
lib/generators/rails_table_preferences/install/templates/demo/orders_controller.rb
lib/generators/rails_table_preferences/install/templates/demo/index.html.erb
lib/generators/rails_table_preferences/javascript/javascript_generator.rb
lib/generators/rails_table_preferences/stylesheets/stylesheets_generator.rb
lib/generators/rails_table_preferences/views/views_generator.rb
lib/tasks/rails_table_preferences.rake
lib/rails_table_preferences.rb
lib/rails_table_preferences/adapters/active_record_columns.rb
lib/rails_table_preferences/adapters/column_like.rb
lib/rails_table_preferences/adapters/controller_params.rb
lib/rails_table_preferences/adapters/ransack.rb
lib/rails_table_preferences/column_definition.rb
lib/rails_table_preferences/configuration.rb
lib/rails_table_preferences/export_payload.rb
lib/rails_table_preferences/legacy_column_adjustment_importer.rb
lib/rails_table_preferences/package_verifier.rb
lib/rails_table_preferences/renderer_registry.rb
lib/rails_table_preferences/settings_normalizer.rb
lib/rails_table_preferences/table_profile.rb
lib/rails_table_preferences/table_state.rb
lib/rails_table_preferences/value_resolver.rb
package.json
README.md
CHANGELOG.md
LICENSE
docs/index.md
docs/quick_start.md
docs/quick_start_ja.md
docs/install_paths.md
docs/resource_tables.md
docs/render_editor_placement_manual_qa.md
docs/resource_table_cell_hooks.md
docs/table_data_attributes.md
docs/resource_table_formatter_contract.md
docs/manual_column_editor_metadata.md
docs/virtual_columns_query_boundary.md
docs/decision_guide.md
docs/scoped_presets.md
docs/preset_selector_scope_labels.md
docs/fixed_columns_and_groups.md
docs/column_overflow.md
docs/resize_auto_fit.md
docs/export_integration.md
docs/accessibility.md
docs/editor_i18n.md
docs/editor_entrypoint_affordances.md
docs/editor_reorder_accessibility.md
docs/header_drag_reorder.md
docs/editor_root_options.md
docs/helper_free_controller_root_urls.md
docs/non_goals.md
docs/visual_overview.md
docs/images/visual-overview-editor-and-table.svg
docs/images/visual-overview-filter-and-pinned-columns.svg
docs/demo.md
docs/sandbox.md
docs/examples.md
docs/troubleshooting.md
docs/manual_qa.md
docs/manual_qa_pr_smoke_matrix.md
docs/filter_panel_viewport_boundary.md
docs/release_checklist.md
docs/package_verification.md
docs/support_matrix.md
docs/controller_integration.md
docs/json_api.md
docs/filter_metadata.md
docs/filter_adapters.md
docs/select_filter_troubleshooting.md
docs/select_filter_option_search_threshold.md
docs/typescript_settings_snapshots.md
docs/javascript_entrypoints.md
docs/javascript_controller.md
```

Keep this list synchronized with `RailsTablePreferences::PackageVerifier::REQUIRED_PATHS`. The runtime entries are representative helper, adapter, registry, formatter, rake task dependency, and resource table files rather than a complete freeze of every file under `lib/`. The legacy column adjustment importer is included because the packaged `lib/tasks/rails_table_preferences.rake` entrypoint loads it directly. The JavaScript entrypoint entries include the packaged `.d.ts` files because TypeScript host apps use them to resolve the public package imports. The fixed list keeps the shared package controller implementation (`app/javascript/rails_table_preferences/controller.js`), while the package export-target check below follows the current `./controller` default export to the package-entrypoint recovery subclass. The resource table partial entries guard the default `resource_table_for` and `tree_resource_table_for` rendering paths that a host app uses without custom partial configuration. The default locale entries guard the shipped English and Japanese copy and the I18n override baseline used by the bundled editor and resource table surfaces. The documentation entries are selected package entrances from the README and docs index rather than a complete freeze of every file under `docs/`; README or docs-index reachability is a strong signal, but not an automatic reason to add a guide to this fixed list. The PR smoke matrix is required because it is the docs-index primary entry for focused release and review evidence boundaries, the render editor placement checklist is required because it is the docs-index primary adoption checklist for `render_editor: false` host placements and package/review evidence, the filter panel viewport boundary guide is required because it is the docs-index primary handoff for short-viewport filter panel positioning and browser-capable QA, the manual column editor metadata guide is required because it is the docs-index primary entry for hand-written table column editor metadata boundaries, the editor reorder accessibility note is required because it is the docs-index primary accessibility companion for package-entrypoint row reorder controls, and the TypeScript settings snapshot guide is required because it is the docs-index primary entry for lightweight declaration helper snapshot maintenance.

## Required path selection criteria

Add a file to `REQUIRED_PATHS` when its absence would make the packaged gem unusable or make a documented public entry point fail after installation. The list is intentionally representative: it protects the most important install, runtime, customization, and documentation surfaces without turning package verification into a full inventory of the repository.

Use these criteria when adding or reviewing required paths:

- Runtime entrypoints that host apps call directly, such as public helpers, controllers, adapters, registry files, resource table partials, rake tasks, copied generator templates, and direct runtime dependencies required by those rake tasks.
- JavaScript package entrypoints, their minimal TypeScript declaration files, and any file named by `package.json` `exports` or top-level `types`. The package-target check also verifies these paths from packaged metadata and follows their static relative import/export references to packaged JavaScript and declaration files.
- Default locale files that shipped views and docs use as the I18n override baseline. `config/locales/en.yml` and `config/locales/ja.yml` are required for this reason; they are not a full `config/` inventory and do not freeze locale wording or key policy.
- Package metadata and release-facing files that should always ship, including `package.json`, `README.md`, `CHANGELOG.md`, `LICENSE`, and this verification guide.
- Focused docs promoted to primary packaged entrances because they guard shipped setup, runtime customization, troubleshooting, support, release, or QA behavior. Current required focused docs include resource table cell hooks, table data attributes, resize auto-fit, render editor placement checklist, editor entrypoint affordances, editor reorder accessibility, header drag reorder, preset selector scope labels, virtual column query boundary, editor root options, helper-free controller root URL guide, manual QA PR smoke matrix, filter panel viewport boundary guide, manual column editor metadata guide, TypeScript settings snapshot guide, select filter troubleshooting, select filter option search threshold, and the JavaScript entrypoint/controller guides because they are primary docs-index entrances for shipped behavior or release/review evidence.
- README or docs-index links that act as orientation, sequencing, or real-host-app checklists are not automatically required paths. For example, `docs/production_integration_checklist.md` and `docs/production_troubleshooting.md` are important adoption guides, but the current verifier does not require them; add them only if the project explicitly promotes them from navigational guides to package-required public entrances and updates `PackageVerifier::REQUIRED_PATHS`, the package verifier spec, and this guide together.
- Scope-boundary docs that keep the packaged release from being mistaken for a broader product surface. `docs/non_goals.md` is required for that reason: it records intentionally deferred query builder, export generation, admin UI, heavy browser test, and complex sticky layout directions that are linked from the docs index and should ship with the release package.
- Visual or other static assets that a required doc directly references, such as the visual overview SVGs.

Do not add every repository file just because it exists. In particular, avoid requiring all docs, all examples, temporary/generated intermediate files, test files, mockups, focused PR smoke notes, or future proposal notes unless they are promoted to a packaged public entry point. A docs page that is only linked from a nearby guide, from a start-here navigation list, or from the PR smoke matrix can stay outside `REQUIRED_PATHS` when the package remains usable without treating that page as a primary entrance. For example, `docs/editor_row_long_label_narrow_smoke.md` remains a focused PR-evidence aid reached from `docs/manual_qa_pr_smoke_matrix.md`; do not require it unless it becomes a README or docs-index primary guide. Likewise, `docs/forced_colors_manual_qa.md` remains a focused high-contrast evidence handoff reached from `docs/manual_qa.md`, and `docs/demo_support_section_smoke.md` remains a focused demo/visual evidence aid reached from `docs/visual_overview.md`; keep both out of `REQUIRED_PATHS` unless they are promoted to primary packaged documentation entrances. `docs/hidden_fields_pagination_evidence.md` follows the same evidence-guide boundary: although the docs index and PR smoke matrix expose it for hidden-field pagination review, leave it out of `REQUIRED_PATHS` while it remains a focused handoff note rather than a required setup, integration, or package-readiness entrance. `docs/preset_name_save_boundary.md` also stays outside `REQUIRED_PATHS` for now: it is a focused copy/QA boundary reached from the preset/i18n docs. Keep it discoverable from those nearby guides and the docs catalog, but do not promote it to a required package entrance unless the project intentionally treats it as a primary setup, integration, QA, or release gate. For a new docs guide, first decide whether README or `docs/index.md` should make it a primary package entrance; if not, leave the fixed list unchanged and document the narrower link from the nearby guide instead.

When a new public helper, partial, package export, packaged declaration, default locale file, README-linked guide that is promoted to a package-required entrance, docs-index primary guide, required rake task dependency, or required visual asset is added, update `RailsTablePreferences::PackageVerifier::REQUIRED_PATHS`, the package verifier spec, and this guide together. If the choice is unclear, leave the fixed list unchanged and document the follow-up question in the relevant Issue or PR instead of broadening the guardrail by default.

## Package metadata and export targets

The package verification task reads the packaged `package.json` and confirms every string target under `exports`, plus the top-level `types` string target, is included in the built gem. For the current package metadata, that means:

```text
package.json#types -> app/javascript/rails_table_preferences/index.d.ts
. types -> app/javascript/rails_table_preferences/index.d.ts
. default -> app/javascript/rails_table_preferences/index.js
./controller types -> app/javascript/rails_table_preferences/controller.d.ts
./controller default -> app/javascript/rails_table_preferences/preset_select_recovery.js
```

The top-level `types` target is reported as `package.json#types` so it remains distinguishable from `exports["."].types` even when both intentionally point at the same declaration file.

The `./controller` default export is the package entrypoint host apps import as `rails_table_preferences/controller`. It currently points at `preset_select_recovery.js`, which subclasses the shared `controller.js` implementation; manual bundler aliases for the package specifier should preserve that same behavior entrypoint instead of bypassing the recovery subclass. The verifier checks that this packaged export target exists and that its relative imports resolve inside the built gem, while the release checklist remains the place to compare README and `docs/javascript_entrypoints.md` manual alias examples against the same target.

After confirming those package target files exist, the verifier scans JavaScript export targets' static relative `import ... from`, side-effect `import`, and `export ... from` references. Extensionless references such as `./controller` and `../controllers/rails_table_preferences_controller` must resolve to packaged JavaScript files, so package verification catches drift where an exported entrypoint ships but one of its internal package files does not.

The verifier performs the same lightweight relative-target check for packaged declaration targets. For example, `app/javascript/rails_table_preferences/index.d.ts` re-exports `./controller`, and package verification now expects that reference to resolve to `app/javascript/rails_table_preferences/controller.d.ts` inside the same built gem. This keeps TypeScript host-app import metadata aligned without adding a full TypeScript compiler check.

This check complements the fixed required-file list: the fixed list catches accidental removal of representative entrypoint files and declarations, while the package target and internal import checks catch drift between `package.json`, JavaScript entrypoint wiring, declaration re-exports, and the gem contents. It is intentionally a lightweight package-content guard, not a replacement for the TypeScript declaration smoke or the manual host-app Vite check in `docs/release_checklist.md`.

The packaged `package.json` is resolver metadata for these gem-packaged JavaScript entrypoints. Its current `private: true` and `version: "0.0.0"` values are intentional metadata boundaries: they do not make the gem a separate npm distribution. The verifier treats drift from `private: true` or `version: "0.0.0"` as a package metadata error so release/package evidence keeps npm distribution policy separate from the Ruby gem package. It still does not treat the JavaScript version as something that must track `RailsTablePreferences::VERSION`. If the project later chooses an npm distribution strategy, document and test that as a separate release policy change.

## Runtime import smoke boundary

`bundle exec rake package:verify` confirms that package metadata, files, JavaScript relative imports, and TypeScript declaration re-exports are internally consistent in the built gem. It does not run a host-app bundler or install frontend dependencies. It also does not parse README or `docs/javascript_entrypoints.md` code blocks to prove their manual resolver aliases still mirror `package.json`; keep that docs-to-metadata comparison in the release checklist's JavaScript entrypoint checks.

The repository JavaScript check adds a narrow Node ESM import smoke for the package root and `rails_table_preferences/controller` specifier. That smoke creates a temporary `node_modules/rails_table_preferences` sandbox from this repository's `package.json` exports and `app/javascript` files, stubs only `@hotwired/stimulus`, normalizes the known extensionless package-internal import for raw Node resolution, and imports the package root default/named controller plus the controller subpath. It catches package specifier resolution and public export drift that `node --check` alone cannot see.

The TypeScript declaration smoke is a separate compiler-level resolver check. It uses the repository declaration files with `moduleResolution: "Bundler"`, a minimal Stimulus declaration stub, and representative imports for the package root, `rails_table_preferences/controller`, and lifecycle event detail types. Keep it scoped to declaration import and typing drift; do not fold it into `bundle exec rake package:verify` or treat it as full host-app Vite evidence.

Treat these smokes as repository-level package-entrypoint evidence, not as full host-app bundler proof. A real Vite / `app/frontend` host app should still verify its resolver aliases, dependency graph, CSS loading, and Stimulus registration through the release checklist or host-app QA path.

## Why this matters

The test suite can pass even if package contents are incomplete. Missing generator templates, copied JavaScript, copied CSS, package entrypoints, packaged declarations, package metadata, gemspec release metadata, rake tasks, rake task dependencies, changelog, default locale files, visual overview assets, README-linked docs, or resource table runtime files usually appear only when the gem is installed into a host Rails app.

## Current CI gate

CI runs:

```bash
bundle exec rspec
node script/check_javascript_syntax.mjs
npm run test:typescript-declarations
node script/check_ci_workflow_permissions.mjs
bundle exec rake build
bundle exec rake package:verify
```

The JavaScript syntax and package import resolution step checks the copied controller plus JavaScript files named by the packaged `package.json` export targets for syntax errors, then smoke-imports the package root and `rails_table_preferences/controller` specifiers in a temporary Node sandbox. The TypeScript declaration smoke independently checks package-root and controller declaration resolution plus representative lifecycle event detail typing under the repository's bundler-style TypeScript resolver. The CI workflow permissions smoke checks that the workflow keeps top-level `permissions: contents: read` and does not request contents or pull-request write permissions. Keep these commands synchronized with `.github/workflows/ci.yml`; `docs/release_checklist.md` lists the same local release-prep commands.

The package verification task also follows the documented package root, top-level types, and controller export targets and checks their packaged internal relative JavaScript and declaration references. That complements the syntax/import smoke, TypeScript declaration smoke, and workflow permissions checks by guarding package export wiring against missing files in the built gem while leaving full host-app bundler behavior and repository release policy to the release checklist's manual evidence.

Manual package inspection is still recommended before tagging a release.
