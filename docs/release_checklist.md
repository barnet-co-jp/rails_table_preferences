# Release checklist

Use this checklist before tagging or publishing a Rails Table Preferences release.

The goal is to catch packaging, generator, documentation, and host-application integration issues that ordinary unit tests may miss.

## 1. Version and changelog

- [ ] Decide the target version.
- [ ] Update the version constant if needed.
- [ ] Move `CHANGELOG.md` entries from `[Unreleased]` to the target version section.
- [ ] For a new release, keep a fresh empty `[Unreleased]` section for post-release work and rename the target version section to `[X.Y.Z] - YYYY-MM-DD` with the actual release date.
- [ ] Do not describe open pull requests, proposal issues, or unmerged roadmap items as released in the dated section; leave them in `[Unreleased]` or out of the release entry until they land.
- [ ] Before moving `Added`, `Changed`, or `Fixed` wording into a dated release entry, cross-check complete-sounding changelog lines against open pull requests, open issues, and `agent:planned` items. If a line depends on an open item, such as numeric-settings normalization work like #1313, leave it out of the dated release entry or rewrite it as non-release context until the implementation lands.
- [ ] Confirm the README release-readiness summary still matches the changelog cutover state before tagging.
- [ ] Confirm `CHANGELOG.md` covers user-facing changes, migration changes, generator changes, JavaScript/CSS changes, and known limitations.
- [ ] Confirm `CHANGELOG.md`, README current scope, and `Product Profile.md` release posture describe the same current `main` product surface.
- [ ] Confirm open pull requests and proposal issues are not described as released behavior unless they have already been merged.
- [ ] Confirm the README and docs describe the released behavior, not planned behavior.
- [ ] Confirm examples use the current public API names.

## 2. Local automated checks

Run the minimum local checks:

```bash
bundle exec rspec
node script/check_javascript_syntax.mjs
npm run test:typescript-declarations
node script/check_ci_workflow_permissions.mjs
bundle exec rake build
bundle exec rake package:verify
```

The JavaScript syntax script checks the copied controller plus the JavaScript targets declared by `package.json` exports, keeping the release checklist aligned when package entrypoints change. The TypeScript declaration smoke separately checks package-root and `rails_table_preferences/controller` declaration resolution plus representative lifecycle event detail typing under the repository's bundler-style TypeScript resolver. The CI workflow permissions smoke checks that the GitHub Actions workflow keeps top-level `permissions: contents: read` and does not request write permissions for contents or pull requests.

Representative Rails compatibility checks are also useful before a release:

```bash
BUNDLE_GEMFILE=gemfiles/rails_7_0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_7_1.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle exec rspec
```

These Rails 7.0 / 7.1 / 7.2 / 8.0 checks match the current representative compatibility matrix. The Rails 7.0 command is the checklist's Ruby 3.1 lower-bound evidence because it runs the Rails lower-bound gemfile on the gemspec's minimum supported Ruby version. Newer host-app Rails releases, such as Rails 8.1, should be treated as additional verification work until a separate support-policy or CI-matrix decision adds them here.

Confirm:

- [ ] RSpec passes.
- [ ] JavaScript syntax script passes for the copied controller and package entrypoints.
- [ ] TypeScript declaration smoke passes for package-root and controller declaration imports.
- [ ] CI workflow permissions smoke passes for the read-only GITHUB_TOKEN policy.
- [ ] Gem package builds.
- [ ] Package verification passes.
- [ ] Representative Rails 7.0 / 7.1 / 7.2 / 8.0 RSpec checks pass.
- [ ] No generated files are unexpectedly changed.

## 3. CI and mergeability checks

Confirm GitHub Actions passes for both the release commit and the latest release-prep pull request:

- [ ] The release commit passes the default RSpec / JavaScript syntax / TypeScript declaration / CI workflow permissions / gem build / package verification job.
- [ ] The latest release-prep pull request passes the same default RSpec / JavaScript syntax / TypeScript declaration / CI workflow permissions / gem build / package verification job.
- [ ] The latest release-prep pull request passes the representative Rails 7.0, Rails 7.1, Rails 7.2, and Rails 8.0 compatibility jobs.
- [ ] Any additional release-time matrix jobs pass in the workflow where they actually run; they are not part of the required PR matrix unless `.github/workflows/ci.yml` adds them.
- [ ] The latest release-prep pull request is compared against current `main`, not only against the `main` commit recorded when the PR body was written.
- [ ] The current `main...branch` compare is not behind or diverged, and GitHub reports the PR as mergeable before using the PR as release evidence.
- [ ] CI evidence names the workflow run for the current head SHA. If combined status is empty, check the GitHub Actions workflow runs for that SHA instead of treating the PR as unchecked.

A successful workflow run on an older PR head is useful history, but it is not enough for release or merge readiness after `main` has moved. Record both the current compare/mergeability state and the head workflow run when refreshing an older PR.

### UI visual evidence and maintainer judgment gates

For release-prep or merge-readiness review, treat rendered UI evidence as separate from CI, source inspection, and behavior specs.

- [ ] If a PR changes visible editor, table, filter panel, status-region, layout, CSS, accessibility, or visual reference behavior, record the PR category and evidence status using [Manual QA PR smoke matrix](manual_qa_pr_smoke_matrix.md).
- [ ] When review asks for desktop, narrow viewport, forced-colors, high-contrast, or other browser-capable proof, name the viewport or mode, the UI state checked, the evidence used, and the remaining browser-capable check.
- [ ] Do not treat CI success, source review, Node behavior specs, DOM/static assertions, or package verification as rendered visual evidence for overlap, clipping, focus visibility, contrast, scroll reachability, or announcement timing.
- [ ] If the agent or reviewer cannot capture browser evidence, leave a clear handoff instead of marking the visual gate complete. The handoff should state the unavailable environment, the strongest substitute used, and whether maintainer visual judgment may close the gate.
- [ ] Maintainer visual judgment may replace a screenshot only when the PR comment or release note names the checked state and why a screenshot artifact is unnecessary for that PR.

Keep this gate proportional. Docs-only changes and source-only guards usually record `Evidence status: not applicable`; UI cue, editor surface, filter panel, dense layout, visual docs, or accessibility changes should either include rendered evidence or carry an explicit `needs-human` handoff.

## 4. Gem package checks

Build and verify the gem package:

```bash
bundle exec rake build
bundle exec rake package:verify
```

Then optionally inspect the built gem or unpack it locally:

```bash
gem contents pkg/rails_table_preferences-*.gem --all
```

See [Package verification](package_verification.md) for the required file list, failure summary format, and manual inspection commands.

If `package:verify` fails, copy the compact summary line into the release-prep PR or checklist note before listing details. It separates required file gaps, missing package export targets, unresolved package-internal JavaScript imports, unresolved package-internal declaration imports, packaged `package.json` metadata errors, and gemspec metadata URL errors so the next reviewer can see which category broke first. Treat packaged `package.json` metadata drift and gemspec release metadata drift as separate categories when triaging the detailed lists.

Pay special attention to generator templates, copied assets, `package.json`, and package JavaScript entrypoints. Missing templates or entrypoints usually appear only when a host app runs a generator or imports the gem through a JS bundler.

### RubyGems publish boundary checks

Package verification confirms the built gem contents. It does not decide RubyGems account policy, trusted publishing, MFA, checksum/provenance handling, or which release artifact a human should publish.

Before publishing, the release owner should confirm:

- [ ] `rails_table_preferences.gemspec` metadata URLs still resolve to the intended homepage, source, changelog, and documentation pages.
- [ ] The RubyGems account or organization that will publish the gem has the expected MFA or account-security posture.
- [ ] The release owner has decided whether this release uses manual `gem push`, trusted publishing, or another approved publishing path; this checklist does not choose the policy.
- [ ] The exact `.gem` artifact selected for publish is the same build output that passed `bundle exec rake package:verify`, or the release note records why a fresh artifact was built and re-verified.
- [ ] A checksum, provenance note, or artifact identifier is recorded in the release-prep PR, tag note, or release note when the release process requires one.
- [ ] A human release owner, not an automated docs agent, reviews the final publish command, account, artifact path, and release gate before any publish action runs.

Use a short evidence block like this in the release-prep PR, tag note, or release note so reviewers can match the selected artifact to the verification result without turning the checklist into publish automation:

```markdown
### Publish evidence

- Target version:
- Built artifact: `pkg/rails_table_preferences-...gem`
- `bundle exec rake package:verify`: pass/fail, run against `<artifact>`
- Checksum / provenance / artifact identifier note:
- Publish method selected by release owner: manual `gem push` / trusted publishing / other approved path
- Human release owner final review: name/date and confirmation that account, MFA or trusted-publishing posture, artifact path, and release gate were reviewed before publishing
```

Keep these checks as release-time evidence. Do not add repository secrets, change RubyGems settings, create a tag, or publish the gem from a docs-only release-readiness task.

## 5. Install generator checks

In a clean or disposable Rails app, run:

```bash
bin/rails generate rails_table_preferences:install
bin/rails db:migrate
```

Confirm:

- [ ] Initializer is created.
- [ ] Migration is created with valid index names.
- [ ] Migration includes `scope_type` and `scope_key`.
- [ ] Migration uses a nullable owner reference for shared, role, and organization presets.
- [ ] Migration runs on SQLite.
- [ ] Migration uses the configured owner model and foreign key when options are passed.
- [ ] JavaScript controller is copied by default.
- [ ] Stylesheet is copied by default.
- [ ] `--skip-javascript` skips JavaScript copying.
- [ ] `--skip-stylesheets` skips stylesheet copying.
- [ ] `--with-demo` copies the demo controller and view.
- [ ] `--with-demo-route` copies the demo controller and view and adds `get "/rails_table_preferences_demo/orders"` once.
- [ ] Re-running `--with-demo-route` does not duplicate an existing representative demo route.
- [ ] Demo route post-install guidance is accurate both when the route is added and when it must be added manually.
- [ ] Post-install messages are accurate for both `stimulus-rails` and Vite / `app/frontend` setups.

## 6. JavaScript entrypoint checks

For frontend integration, confirm:

- [ ] `app/javascript/controllers/rails_table_preferences_controller.js` is packaged for copy-based `stimulus-rails` use.
- [ ] `app/javascript/rails_table_preferences/controller.js` is packaged for `rails_table_preferences/controller` imports.
- [ ] `app/javascript/rails_table_preferences/index.js` is packaged for package-root imports.
- [ ] `app/javascript/rails_table_preferences/controller.d.ts` and `app/javascript/rails_table_preferences/index.d.ts` are packaged for TypeScript host-app imports.
- [ ] `package.json` is packaged and exposes `.` and `./controller` exports, including the top-level `types` target and each `exports.*.types` declaration target.
- [ ] README and `docs/javascript_entrypoints.md` Vite/manual bundler alias examples for `rails_table_preferences/controller` still point at the same behavior entrypoint as `package.json` `exports["./controller"].default`.
- [ ] Package verification confirms the declaration targets and their relative `.d.ts` re-exports resolve inside the built gem.
- [ ] TypeScript declaration smoke confirms package-root and `rails_table_preferences/controller` imports resolve under the repository compiler fixture; keep full host-app Vite / `app/frontend` TypeScript evidence separate from this repository smoke.
- [ ] Treat Node.js 20 as the repository CI runtime for JavaScript syntax and package-entrypoint checks, not as a package consumer `engines` requirement; if that policy changes, update `package.json`, Support matrix, JavaScript entrypoints, and package verification together.
- [ ] A Vite / `app/frontend/entrypoints/application.js` host app can register `rails_table_preferences/controller` as `rails-table-preferences`.
- [ ] A default `stimulus-rails` host app still works with the copied controller.

## 7. Demo and sandbox checks

Run through the demo or sandbox flow:

```bash
bin/rails generate rails_table_preferences:install --with-demo-route
bin/rails db:migrate
```

Mount the engine for the bundled JSON API. If you run `--with-demo` instead of `--with-demo-route`, also add the demo route manually:

```ruby
mount RailsTablePreferences::Engine, at: "/rails_table_preferences"
get "/rails_table_preferences_demo/orders", to: "rails_table_preferences_demo/orders#index"
```

Confirm:

- [ ] The demo page renders.
- [ ] The host app has a working current owner method, usually `current_user`.
- [ ] Private `current_user` methods work.
- [ ] The `Current owner` summary matches the owner record that save/reload will persist into.
- [ ] Japanese demo labels render.
- [ ] Ignored demo columns do not appear in the editor.
- [ ] Column visibility works.
- [ ] Column order works from the editor.
- [ ] Column order works from table-header drag.
- [ ] Column width resize works.
- [ ] Save persists settings.
- [ ] Reload restores saved settings.
- [ ] Filter panel opens.
- [ ] Sortable header click cycles sort state.
- [ ] Fixed/pinned column hooks are present when configured.
- [ ] The grouped header row still matches the visible leaf headers after changing visibility or order, saving, and reloading.
- [ ] Read-only scoped presets do not expose destructive normal-user controls.
- [ ] The `Current scope context` summary matches the scope context returned by the host app.
- [ ] Shared preset examples appear in the preset selector.
- [ ] Matching role context shows the role preset example in the preset selector.
- [ ] Matching organization context shows the organization preset example in the preset selector.
- [ ] With no owner default, role default resolution still wins before organization and shared defaults.
- [ ] With no owner or matching role default, organization default resolution still wins before shared defaults.
- [ ] The export payload preview excludes hidden columns by default.
- [ ] The export payload preview follows the saved visible-column order.
- [ ] Async preset actions update the bundled status region with understandable progress and result copy.
- [ ] Async preset actions temporarily disable controls and recover after success or failure.

See also:

- [Demo screen generator](demo.md)
- [Sandbox Rails app verification](sandbox.md)
- [Manual QA checklist](manual_qa.md)

## 8. API and controller behavior checks

Confirm the mounted engine JSON API still behaves as expected:

- [ ] `GET /rails_table_preferences/preferences/:table_key`
- [ ] `POST /rails_table_preferences/preferences/:table_key`
- [ ] `GET /rails_table_preferences/preferences/:table_key/:name`
- [ ] `PATCH /rails_table_preferences/preferences/:table_key/:name`
- [ ] `PUT /rails_table_preferences/preferences/:table_key/:name`
- [ ] `DELETE /rails_table_preferences/preferences/:table_key/:name`

Confirm scoped preference behavior:

- [ ] Owner presets are editable by the owner.
- [ ] Shared presets can be selected by users.
- [ ] Role presets are available only when the scope context matches.
- [ ] Organization presets are available only when the scope context matches.
- [ ] Default resolution prefers owner, then role, then organization, then shared.

Confirm controller integration behavior:

- [ ] `rails_table_preference_settings` returns normalized settings.
- [ ] `rails_table_preference_params` returns plain controller params by default.
- [ ] `rails_table_preference_params(adapter: :ransack)` returns Ransack params.
- [ ] `rails_table_preference_merged_params` merges with host controller params.
- [ ] `rails_table_preference_export_payload` returns ordered export columns and headers.
- [ ] Private current-owner methods work.

## 9. Documentation checks

Check the main user paths:

- [ ] README remains a short newcomer-facing entry point and links to the full docs index.
- [ ] README links directly to the primary start-here paths: Quick start, Japanese quick start, Production integration checklist, Install path options, Support matrix, Decision guide, Demo screen generator, and Troubleshooting.
- [ ] README links to Product Profile, AGENTS.md, and CHANGELOG.md for maintainer orientation.
- [ ] `docs/index.md` remains the detailed hub for focused guides that do not need a direct README link.
- [ ] When a new focused guide is added, confirm it is reachable from `docs/index.md` or from the most relevant neighboring guide. Add a README link only when the guide becomes a primary start-here path, not just because the file exists.
- [ ] For a new focused guide, confirm whether `docs/quick_start_ja.md` needs only a low-drift link or short summary update. Do not copy detailed English guide steps into the Japanese quick start unless the first-run Japanese orientation actually changed.
- [ ] `docs/index.md` links to the current start-here guides, core topic guides, manual QA, release checklist, package verification, JavaScript entrypoints, mounted JSON API, controller integration, filter docs, and maintainer entry docs.
- [ ] Focused docs that README mentions only through the docs index, such as Scoped presets, Fixed columns and column groups, Export integration, Accessibility baseline, Sandbox verification, Manual QA, Release checklist, Package verification, and JavaScript entrypoints, remain reachable from `docs/index.md`.
- [ ] README, `CHANGELOG.md`, and `Product Profile.md` stay synchronized on initial release posture, support matrix, current scope, responsibility boundary, and docs entrypoints.
- [ ] `docs/quick_start_ja.md` remains a low-drift entry point: its links and short summaries follow the current README and focused English docs for install/package entrypoints, production integration/support matrix, filter/sort/scoped preset/export/resource table surfaces, and demo/sandbox/manual QA/release/package verification without becoming a full translation.
- [ ] `Product Profile.md` is synchronized with the released product surface, responsibility boundary, and release posture without copying focused guide details.
- [ ] Installation docs mention engine mount.
- [ ] Installation docs mention Vite / `app/frontend` controller registration.
- [ ] Demo docs explain both the `--with-demo-route` option and the manual demo route fallback when using `--with-demo`.
- [ ] `docs/production_integration_checklist.md` stays discoverable as the bridge from quick start or demo verification to a real host-app index screen.
- [ ] `docs/demo.md`, `docs/manual_qa.md`, and `docs/release_checklist.md` stay aligned on the current demo verification surface, including owner/scope summaries, scoped preset precedence, export payload preview, grouped-header consistency, and async preset recovery.
- [ ] Troubleshooting covers Stimulus, Vite entrypoints, CSS, CSRF, auth, current user, scoped presets, filter/sort, and ignored columns.
- [ ] Responsibility boundary is clear: host app owns database search, authorization, complex sticky layout polish, export file generation, and shared preset admin UI.

## 10. Backward compatibility checks

If changing settings structure, helper options, or JSON API shape, confirm:

- [ ] `SettingsNormalizer` still accepts legacy `ColumnAdjustment`-style keys.
- [ ] Existing saved settings do not reintroduce ignored columns.
- [ ] Missing filters/sorts normalize to empty neutral values.
- [ ] Existing controller params adapter behavior is preserved.
- [ ] Existing Ransack adapter behavior is preserved.
- [ ] Current column metadata overrides stale saved metadata for labels, filters, sortable state, and pinned state.
- [ ] Run the display preference behavior section in [Manual QA checklist](manual_qa.md) when changing column labels, overflow metadata, fixed/pinned metadata, or reset/default handling.

## 11. Release notes

Before publishing, summarize:

- [ ] New features.
- [ ] Breaking changes, if any.
- [ ] Migration or generator changes.
- [ ] JavaScript/CSS integration changes.
- [ ] Known limitations.
- [ ] Upgrade notes for existing users.

Use `CHANGELOG.md` as the detailed release history. Use the release note as a short adoption-facing summary that a host-app maintainer can scan before trying the gem. Do not copy open pull requests, proposal issues, or unmerged behavior into the release note as released support.

For a new release, start from this compact template in the release-prep PR body or GitHub release draft:

```markdown
## Summary

- Rails Table Preferences provides owner-aware table display preferences for Rails index screens, including columns, filters, sorts, scoped presets, and export payload metadata.
- The gem is intended to layer onto existing host-app queries, authorization, search forms, and CSV/Excel/report generation rather than replacing them.

## Upgrade notes

- Run the install generator and migration before using the bundled JSON API or helpers.
- Mount the engine when using bundled preset save/load/delete endpoints.
- Register either the copied Stimulus controller or the package entrypoint; do not register both for the same screen.
- Treat existing `ColumnAdjustment` import, owner model configuration, and scoped preset setup as host-app integration work.

## Known limitations

- Host apps own database search, joins, authorization, pagination, and export file generation.
- Host apps own complex sticky layout polish, grouped header markup, and final dense-table CSS verification.
- Shared, role, and organization presets are supported as data scopes, but a full administrative UI for managing them is outside this release.
- Newer Rails releases outside the documented representative CI matrix need additional host-app verification before production adoption.

## Checks and evidence

- CI on the release commit:
- `bundle exec rake package:verify` result:
- Demo or sandbox verification:
- Manual QA / host-app smoke:
- Known-good rollback target:
```

Keep the template current with the landed `main` product surface. If a line depends on an open pull request, proposal issue, publish policy, or dated changelog cutover, leave it out until the relevant decision lands.

## 12. Publish or tag

When everything is ready:

- [ ] Ensure the working tree is clean.
- [ ] Tag the release.
- [ ] Push the tag.
