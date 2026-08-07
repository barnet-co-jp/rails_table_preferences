# Manual QA checklist

Use this checklist before asking host application users to try Rails Table Preferences in a real workflow.

The automated suite covers Ruby behavior, generator output, request behavior, helper output, adapters, and source-level JavaScript invariants. Manual QA focuses on browser behavior, host app integration, accessibility, and visual/UX issues that are difficult to verify with the current test suite.

## Quick smoke before the full checklist

Use this short path when you need a first browser confidence check for a docs PR, release candidate, generated demo update, or early host-app adoption pass. It is not a replacement for the full checklist below. Run the full checklist before broader host-app rollout, before changing custom integration points, or when a quick smoke reveals anything suspicious.

- [ ] Open the generated demo or a representative host-app list screen and confirm the editor and table both render.
- [ ] Hide one non-sensitive column, apply the change, and confirm the table updates without hiding required actions or links.
- [ ] Change one editor order input, apply the change, and confirm the table order updates without using drag and drop.
- [ ] If the screen uses the package entrypoint, search for one editor row and use the row up/down controls once; if it uses a copied controller, record that the numeric order input remains the keyboard-friendly fallback instead.
- [ ] If the screen uses the package entrypoint, use Show all columns and Hide all columns once and confirm the status region announces each bulk visibility result; if it uses a copied controller, record whether that packaged status feedback was ported or intentionally unavailable.
- [ ] Save the preset, reload the page, and confirm the saved visibility/order state returns.
- [ ] Apply one representative text/select/date/number filter and confirm the host app or demo rows narrow as expected.
- [ ] Click one sortable header and confirm the visible row order or outgoing host-app sort params change as expected.
- [ ] Switch to another owner or demo owner link and confirm saved presets do not leak between owners.
- [ ] When the generated demo is the smoke surface, use the `Verification task map` near the top to jump to the support sections that match the changed area: `Current owner`, `Current scope context`, `Demo state reset`, `Async failure check`, hidden fields preview, or export payload preview. Use [Demo screen generator](demo.md) as the detailed source of truth and record any sections intentionally handed off.
- [ ] For hidden fields preview or export payload preview evidence, record whether the copy control succeeded. If the copy button is disabled or reports a copy failure, select the visible preview text manually and record that text as the evidence instead.
- [ ] Open one filter panel or preset action with keyboard focus and confirm focus, labels, and status copy remain understandable.
- [ ] Check one representative phone-like narrow viewport or narrow container, such as 375px or 390px-equivalent, and one long-label or long-value row to confirm editor controls, filter panels, and fixed columns do not overlap or become unreachable; record the viewport or container width used and leave multi-width coverage to the full checklist when needed.

After this quick smoke, continue into the relevant sections below for the feature area you changed. For release sign-off or host-app launch, complete the full checklist and record any skipped areas in the sign-off notes.

## Full checklist map

Use this map after the quick smoke when you already know which manual QA areas matter. It is only a jump list: keep using the track-based starting points for scope selection, and do not treat this map as a replacement for the checklist items themselves.

- [1. Environment and installation](#1-environment-and-installation)
- [2. Owner/current user configuration](#2-ownercurrent-user-configuration)
- [3. Basic rendering](#3-basic-rendering)
- [4. Display preference behavior](#4-display-preference-behavior)
- [5. Preset behavior](#5-preset-behavior)
- [6. Scoped preset behavior](#6-scoped-preset-behavior)
- [7. API and network behavior](#7-api-and-network-behavior)
- [8. Filter UI behavior](#8-filter-ui-behavior)
- [9. Sort UI behavior](#9-sort-ui-behavior)
- [10. Fixed columns and column groups](#10-fixed-columns-and-column-groups)
- [11. Export integration](#11-export-integration)
- [12. Controller params integration](#12-controller-params-integration)
- [13. Existing search form integration](#13-existing-search-form-integration)
- [14. Ransack integration](#14-ransack-integration)
- [15. Ignored columns and sensitive fields](#15-ignored-columns-and-sensitive-fields)
- [16. Accessibility baseline](#16-accessibility-baseline)
- [17. Customization](#17-customization)
- [18. Browser and layout checks](#18-browser-and-layout-checks)
- [19. Regression checklist from early implementation issues](#19-regression-checklist-from-early-implementation-issues)
- [Sign-off](#sign-off)

## Track-based starting points

Use these track entries to choose the first manual QA scope for small PRs. They do not replace the quick smoke, the full checklist, or the [Manual QA PR smoke matrix](manual_qa_pr_smoke_matrix.md). Use the smoke matrix when a PR comment needs category-specific evidence wording, escalation criteria, or browser-capable handoff language.

- `track:docs`: start with source-of-truth review rather than browser smoke unless the text claims a rendered state. Check changed links, commands, option names, issue or PR references, and the neighboring guide that owns the behavior. If the docs-only change touches helper-free, custom partial, or host-app-owned table markup, use the [Helper-free table root manual QA](helper_free_table_manual_qa.md) focused checklist for table-root and wrapper-root evidence wording before expanding to the full checklist. If README, docs index, English quick start, or a focused entrypoint changes, compare the low-drift Japanese quick start links and summaries when relevant.
- `track:design`: start with the quick smoke plus the UI, CSS, accessibility, or high-contrast sections touched by the PR. For editor layout, action grouping, filter panel reachability, forced-colors, focus visibility, or visual docs, use the smoke matrix category to record rendered evidence or an explicit browser-capable handoff. When the PR specifically needs forced-colors or high-contrast evidence, use the [Forced-colors manual QA note](forced_colors_manual_qa.md) for the focused browser/mode record.
- `track:feature`: start with the quick smoke, then run the sections for the changed public surface, such as presets, filters, sort, fixed columns, exports, controller params, generator/demo flow, JavaScript entrypoints, or resource table helpers. Add the release or package verification sections only when the PR changes package contents, setup paths, or release-facing behavior.
- `track:quality`: start with the invariant or regression area the PR protects, then run the smallest browser/manual check that would reveal the same failure in a real screen. Keep source-level specs, CI results, and browser evidence separate; use the smoke matrix when the PR needs a review-state handoff instead of more checklist work.

For mixed-track PRs, choose the strictest entry that matches the user-visible risk. Escalate to the full checklist for release candidates, host-app launch checks, custom integration points, multi-category changes, or any suspicious quick-smoke result.

## 1. Environment and installation

- [ ] Create or select a Rails application for manual testing.
- [ ] Add the gem to the host app Gemfile.
- [ ] Run `bundle install`.
- [ ] Run the install generator.
- [ ] Confirm the generated initializer exists.
- [ ] Confirm the generated migration exists.
- [ ] Confirm the copied Stimulus controller exists.
- [ ] Confirm the copied stylesheet exists.
- [ ] Run `bin/rails db:migrate`.
- [ ] Mount `RailsTablePreferences::Engine` in `config/routes.rb`.
- [ ] Confirm the configured `mount_path` matches the route mount path.

## 2. Owner/current user configuration

- [ ] Confirm the default `current_user` method works, or configure `current_user_method`.
- [ ] Confirm the configured owner model matches the generated migration.
- [ ] Confirm preferences are saved against the expected owner record.
- [ ] Test at least two different owners and confirm preferences do not leak between owners.
- [ ] If you use the generated demo example, confirm `Host app owner`, `Demo owner A`, and `Demo owner B` switch the owner context without changing authentication code.
- [ ] If you use the generated demo example, confirm the `Current owner` summary follows the active owner link before saving or loading presets.

## 3. Basic rendering

- [ ] Render `table_preferences_editor` on a list screen.
- [ ] Render `table_preferences_table_tag` around the target table.
- [ ] Confirm the editor is visible.
- [ ] Confirm the target table is visible.
- [ ] If using `resource_table_for` or `tree_resource_table_for` with `caption:`, confirm the rendered caption is a short semantic table name and does not duplicate the page heading or surrounding instructions.
- [ ] If a resource table profile formatter reads associations, confirm the host app relation preloads those associations and that a query log or existing N+1 guard stays clean for representative rows.
- [ ] Confirm every target header and cell has the matching `data-rails-table-preferences-column-key`.
- [ ] Confirm Japanese column labels are shown when host app locale entries are present.
- [ ] Confirm explicit `label:` values override locale lookup.
- [ ] Render two editors on one page and confirm each preset label focuses the matching select/input.

## 4. Display preference behavior

- [ ] Hide a column from the editor and apply it.
- [ ] Show the column again and apply it.
- [ ] Reorder columns by dragging editor rows.
- [ ] Reorder columns by dragging table headers directly.
- [ ] Using only the keyboard, change a column's numeric order input, move to `適用`, and confirm the table order changes.
- [ ] On package entrypoint screens, use the editor row search to find a column by label, key, or group text and confirm applying or saving does not drop rows hidden by the search.
- [ ] On package entrypoint screens, move a filtered editor row with the row up/down controls, then apply and confirm the visible order changes while numeric order inputs refresh.
- [ ] On copied-controller screens, confirm those package entrypoint-only search and row move controls are not assumed to exist; use the numeric order input plus `適用` as the documented fallback.
- [ ] At a narrow width or on a touch device, confirm the editor order input remains usable as the fallback when table-header drag is awkward or unavailable.
- [ ] At 320px, 375px, and 390px-equivalent phone-like viewport widths, and in any narrow container used by the host layout, confirm long Japanese and long unbroken editor row labels wrap without covering the drag handle, visible checkbox, or order/width/truncate inputs.
- [ ] Resize a column using the header resize handle.
- [ ] Double-click a header resize handle and confirm the column auto-fits to its visible content.
- [ ] If the screen uses the package entrypoint, focus a header resize handle, press Enter or Space, and confirm it auto-fits like double-click; if the screen uses the copied controller, record whether that package-only shortcut was ported or intentionally unavailable.
- [ ] On package entrypoint screens, confirm the status region announces the Enter or Space auto-fit success copy; on copied-controller screens, do not treat that package-only status copy as required unless the host app has ported it.
- [ ] Confirm the resize hit area is easy enough to grab.
- [ ] Hover the resize handle and confirm a visible resize affordance appears without shifting header text, filter buttons, or sort indicators.
- [ ] Move keyboard focus to the resize handle and confirm the focus-visible affordance remains visible with long labels and nearby header controls.
- [ ] Change a width value in the editor and apply it.
- [ ] Change a truncation value and confirm long text is truncated.
- [ ] Add representative `wrap`, `nowrap`, and `ellipsis` columns and confirm each overflow mode stays visually distinct.
- [ ] Apply display changes, save the preset, reload the page, and confirm current column labels, width/truncation values, and overflow modes are still taken from the current column definition where the saved settings do not override them.
- [ ] With a stale saved preset or fixture, confirm current `label:`, `overflow:` / `default_overflow:`, and fixed/pinned metadata override old saved display metadata instead of keeping obsolete labels or hooks.
- [ ] In `resource_table_for` and `tree_resource_table_for`, hide every column while records still exist and confirm the default partial shows the all-hidden fallback row instead of an empty `<tr>` or invalid `colspan="0"` markup.
- [ ] Open the editor in the default display state and confirm the reset button is disabled rather than presenting a meaningful no-op.
- [ ] Reset settings after a saved display change and confirm labels, pinned/fixed hooks, and overflow behavior return to the current column definition defaults.
- [ ] Reset settings and confirm the table returns to default display settings and the status region announces the reset result.
- [ ] Confirm the visible reset helper explains that unsaved editor changes are discarded and defaults are restored without relying on hover text.
- [ ] Hover or focus the reset button and confirm the button hint matches the visible reset helper.

## 5. Preset behavior

- [ ] Save the default preset.
- [ ] Reload the page and confirm the saved default preset is applied.
- [ ] Save as a new named preset.
- [ ] Select the named preset and confirm it loads.
- [ ] Update the named preset and confirm changes persist.
- [ ] Mark a preset as default.
- [ ] Reload without an explicit name and confirm the default preset loads.
- [ ] Delete a non-default preset.
- [ ] Try deleting a preset and confirm the UI remains usable afterwards.
- [ ] Confirm the bundled action hint explains the difference between apply, save, and save as new.
- [ ] Confirm the preset selector helper copy explains that it chooses which saved settings to load or switch to.
- [ ] Confirm the preset name helper copy explains that save and save as new use that field as the edited preset name.
- [ ] Confirm save/load/delete actions update the bundled status region with understandable progress and result copy.
- [ ] Confirm async preset actions temporarily disable the preset select, preset name, default checkbox, action buttons, and generated editor row inputs.
- [ ] Confirm drag-reordering editor rows does not start while an async preset action is running.
- [ ] Confirm those controls re-enable after success.
- [ ] Trigger at least one API failure and confirm the matching action-specific failure status appears and the controls recover.
- [ ] Prefer a lightweight browser-devtools failure such as request blocking, then unblock it and confirm the same action succeeds normally.
- [ ] If you use the generated demo example, use the `Async failure check` section to make one save, load, or delete request fail exactly once, then retry the same action and confirm it succeeds.

## 6. Scoped preset behavior

- [ ] Create or seed a shared preset and confirm it appears in the preset selector.
- [ ] Create or seed a role preset and confirm it appears only for matching role context.
- [ ] If you use the generated demo example, configure `scope_context_method = :table_preference_scope_context` once, use `Role preset lane`, and confirm `担当ビュー [role:operations]` appears.
- [ ] Create or seed an organization preset and confirm it appears only for matching organization context.
- [ ] If you use the generated demo example, configure `scope_context_method = :table_preference_scope_context` once, use `Organization preset lane`, and confirm `東京組織ビュー [organization:tokyo-hq]` appears.
- [ ] If you use the generated demo example, use `Host app context`, `Owner-only baseline`, `Role preset lane`, and `Organization preset lane` to switch the scope context without editing `ApplicationController` between requests.
- [ ] If you use the generated demo example, confirm the `Current scope context` summary follows the active scope link before reading the preset selector.
- [ ] If you use the generated demo example, use `Demo state reset` before repeating scoped/default precedence checks when earlier save testing may have created owner-scoped demo presets.
- [ ] Confirm preset options show enough scope context to distinguish owner/shared/role/organization presets.
- [ ] Confirm owner, role, organization, and shared presets are grouped in the selector when multiple scope buckets are returned, while single-scope owner presets remain easy to scan.
- [ ] Confirm owner default is preferred over role, organization, and shared defaults.
- [ ] Confirm role default is preferred over organization and shared defaults when there is no owner default.
- [ ] In the generated demo flow, use `Owner-only baseline` to clear representative role/organization context and compare the shared baseline again.
- [ ] In the generated demo flow, clear any owner default and confirm `担当ビュー [role:operations]` wins before `共有ビュー [shared]`.
- [ ] In the generated demo flow, use `Organization preset lane` without a matching role default and confirm `東京組織ビュー [organization:tokyo-hq]` wins before `共有ビュー [shared]`.
- [ ] Confirm shared presets are selectable by normal users.
- [ ] Confirm shared/role/organization presets are not deleted from the normal user-facing editor.
- [ ] Confirm the read-only hint explains that saving changes from a read-only scoped preset creates or updates an owner preset, rather than overwriting the shared preset.
- [ ] Confirm host app authorization protects any admin UI for shared/role/organization preset management.

## 7. API and network behavior

Use browser devtools while saving/loading presets.

For a quick failure-path check, temporarily block one preference API URL in browser devtools, confirm the failed request surfaces the matching action-specific failure state, then remove the block and retry once.

- [ ] Confirm `GET /rails_table_preferences/preferences/:table_key` returns the preset collection.
- [ ] Confirm `POST /rails_table_preferences/preferences/:table_key` creates a preset.
- [ ] Confirm `GET /rails_table_preferences/preferences/:table_key/:name` loads a preset.
- [ ] Confirm `PATCH /rails_table_preferences/preferences/:table_key/:name` updates a preset.
- [ ] Confirm `DELETE /rails_table_preferences/preferences/:table_key/:name` deletes a preset.
- [ ] Confirm JSON requests include the Rails CSRF token.
- [ ] Confirm authenticated requests do not redirect to the login page.
- [ ] Confirm API failures show enough browser/log detail to diagnose.

## 8. Filter UI behavior

- [ ] Add a text filter column and confirm the filter button appears.
- [ ] Open the filter panel.
- [ ] Confirm only the open filter button exposes `aria-expanded="true"`.
- [ ] Confirm focus moves into the filter panel when it opens.
- [ ] Press `Escape` and confirm the panel closes and focus returns to the triggering filter button.
- [ ] Re-open the panel and apply a `contains` condition.
- [ ] Confirm switching the operator while the panel stays open updates the visible input controls immediately.
- [ ] Confirm choosing `between` replaces the single value input with `from` / `to` inputs.
- [ ] Confirm choosing `blank` / `present` or boolean operators removes unnecessary value inputs.
- [ ] Confirm the active filter button exposes a short operator/value summary through hover title or accessible name.
- [ ] Apply an `equals` condition.
- [ ] Apply a blank/present condition.
- [ ] Clear the filter.
- [ ] Add a select filter column and choose one or more values.
- [ ] In a short viewport, open a filter panel that includes a multi-select or several fields and confirm the panel scrolls enough to reach Apply and Clear.
- [ ] Add a date filter column and set from/to values.
- [ ] Add a number filter column and set from/to values.
- [ ] Confirm multiple active filters still leave header controls usable while exposing summary context per column.
- [ ] Confirm filter panel layering is not clipped by the surrounding layout.
- [ ] Confirm opening one filter panel closes or does not visually conflict with another.
- [ ] Confirm page scroll, container scroll, or viewport resize closes the panel instead of leaving it detached from the header context.
- [ ] Confirm filter buttons do not reopen or change state while an async preset action is running.

## 9. Sort UI behavior

- [ ] Add `sortable: true` to a column.
- [ ] Click the header and confirm ascending sort state is shown.
- [ ] Click again and confirm descending sort state is shown.
- [ ] Click again and confirm sort is cleared.
- [ ] Confirm non-sortable columns do not change sort state.
- [ ] Confirm clicking a filter button does not toggle sort.
- [ ] Confirm dragging/resizing a header does not accidentally toggle sort.
- [ ] Confirm `aria-sort` changes appropriately.
- [ ] Confirm sortable headers do not change state while an async preset action is running.

## 10. Fixed columns and column groups

- [ ] Add `fixed: true` or `pinned: true` to a column.
- [ ] Confirm pinned cells receive pinned/fixed class and data hooks.
- [ ] Confirm the pinned column remains visible while horizontally scrolling the table container.
- [ ] While horizontally scrolled, confirm focused links, buttons, inputs, and filter buttons remain visible and clickable near pinned cells.
- [ ] Confirm focus outlines are not clipped by the scroll wrapper and are not hidden behind pinned header or body cells.
- [ ] Confirm pinned cells use an opaque background and app-specific `z-index` order so scrolled content, filter panels, dropdowns, and surrounding app chrome do not visually conflict.
- [ ] If you use the generated demo example, confirm the scroll wrapper keeps `受注番号` visible while the rest of the table moves.
- [ ] Confirm multiple pinned columns do not overlap in the tested layout.
- [ ] Resize a pinned column and confirm pinned offsets are still correct.
- [ ] Reorder columns and confirm pinned offsets are recalculated.
- [ ] Hide a pinned column and confirm later pinned columns shift correctly.
- [ ] Add `group:` metadata to columns.
- [ ] Use `table_preferences_column_groups` in grouped header markup and confirm `colspan` values are correct.
- [ ] If you use the generated demo example, confirm that after changing visibility or order, saving, and reloading, the grouped header row still matches the visible leaf headers.
- [ ] Confirm leaf header cells still have `data-rails-table-preferences-column-key`.
- [ ] Confirm pinned-column resize and header drag do not start while an async preset action is running.

## 11. Export integration

- [ ] Use `rails_table_preference_export_payload` in a controller.
- [ ] Confirm hidden columns are excluded by default.
- [ ] Confirm `include_hidden: true` includes hidden columns when intended.
- [ ] Confirm exported column order follows saved display order.
- [ ] Confirm exported headers use the expected labels.
- [ ] Confirm `export_key` is used when display key and export method differ.
- [ ] Confirm group metadata is available for grouped CSV/Excel headers.
- [ ] If you use the generated demo example, confirm the export payload preview excludes hidden columns and follows the saved visible-column order after save and reload.
- [ ] Confirm host app authorization decides whether sensitive values are exportable.

## 12. Controller params integration

- [ ] Use `rails_table_preference_params` in a controller.
- [ ] Confirm saved text filter state becomes the expected host app param.
- [ ] Confirm saved select filter state becomes the expected host app param.
- [ ] Confirm saved date range filter state becomes the expected host app params.
- [ ] Confirm saved sort state becomes the expected sort param.
- [ ] Confirm `sort_param:` maps a display column key to the host app sort key.
- [ ] Confirm the host app search layer executes the final merged params.

## 13. Existing search form integration

- [ ] Add `table_preferences_hidden_fields` to an existing search form.
- [ ] Confirm hidden fields are generated for saved filters.
- [ ] Confirm array params render with `[]` names where expected.
- [ ] Confirm blank filter values are not submitted unnecessarily.
- [ ] Confirm normal user-entered search params still work.
- [ ] If you use the generated demo example, confirm the hidden fields preview updates after reload, keeps expected `[]` array param names, omits blank values, and preserves saved boolean `false` values.
- [ ] Confirm saved preference params and user-entered params merge in the intended precedence order.

## 14. Ransack integration

- [ ] Use `adapter: :ransack` in a controller.
- [ ] Confirm text filters become expected Ransack predicates.
- [ ] Confirm date/number filters become expected Ransack predicates.
- [ ] Confirm sorts become `s` params.
- [ ] Use `table_preferences_hidden_fields` with `namespace: :q`.
- [ ] Confirm generated hidden fields use `q[...]` names.

## 15. Ignored columns and sensitive fields

- [ ] Mark a column with `ignored: true` and confirm it does not appear in the editor.
- [ ] Pass `ignored_columns:` and confirm matching columns do not appear in the editor.
- [ ] Confirm old saved settings cannot reintroduce ignored columns into the editor payload.
- [ ] Confirm the host application does not render sensitive ignored columns in HTML.
- [ ] Confirm authorization/query selection still protects sensitive values server-side.

## 16. Accessibility baseline

- [ ] Confirm all editor controls can receive keyboard focus.
- [ ] Confirm focus order is understandable.
- [ ] Confirm preset select, preset name, default checkbox, and action buttons have labels.
- [ ] Confirm the action row helper text or accessible names explain the difference between apply, save, and save as new.
- [ ] Confirm the preset selector helper copy or accessible description explains that it loads or switches the saved preset.
- [ ] Confirm the preset name helper copy or accessible description explains that save and save as new use that field as the edited preset name.
- [ ] Confirm the reset visible helper, hover text, or accessible name explains that current edits are discarded and defaults are restored.
- [ ] Confirm the bundled `role="status"` region announces preset action progress and result copy.
- [ ] Confirm `resource_table_for` and `tree_resource_table_for` captions are present when a short semantic table name is needed, and that longer explanations remain in host-app headings or copy.
- [ ] Confirm filter buttons expose a useful accessible label.
- [ ] Confirm active filter buttons update `aria-pressed`.
- [ ] Confirm active filter buttons expose a short operator/value summary in `title` or `aria-label`.
- [ ] Confirm the open filter button updates `aria-expanded` and `aria-controls`.
- [ ] Confirm bundled filter panel focus returns to the triggering button when closed with `Escape`.
- [ ] Confirm sortable headers update `aria-sort`.
- [ ] Confirm resize handles expose the visible column name, not only an internal column key.
- [ ] Confirm resize handles show a visible focus indicator when reached by keyboard.
- [ ] If using the package entrypoint, confirm Enter or Space on the focused resize handle triggers auto-fit without implying arrow-key resizing is available.
- [ ] On package entrypoint screens, confirm the bundled status region announces visibility bulk and focused resize auto-fit success; on copied-controller screens, only require those messages if the host app has ported the package-entrypoint behavior.
- [ ] Confirm numeric order inputs provide a keyboard-friendly alternative to drag and drop.
- [ ] On package entrypoint screens, confirm the row search field has a visible label or accessible name and that row up/down controls expose the moved column name.
- [ ] On copied-controller screens, confirm the row search and row up/down package controls are not promised unless the host app has ported them; numeric order inputs remain the fallback.
- [ ] Confirm keyboard-only reordering can be completed with the numeric order input and `適用`, without using editor-row drag or table-header drag.
- [ ] Confirm touch or narrow-viewport users can use editor order inputs as the fallback when direct table-header drag is not comfortable.
- [ ] Confirm read-only scoped presets disable destructive/default controls.
- [ ] Confirm read-only scoped presets explain that saves fall back to the owner preset path without implying they only create a brand-new preset.
- [ ] Confirm async preset actions temporarily disable preset controls and re-enable them after success or failure.
- [ ] Confirm async preset actions also keep editor row inputs, drag handles, filter buttons, resize handles, and sortable headers from changing state until the request finishes.
- [ ] Confirm sticky/fixed columns do not cover focused links, buttons, or inputs while the table is horizontally scrolled.
- [ ] Confirm custom host app scroll containers, backgrounds, and `z-index` overrides keep focus outlines and interactive cell content visible.
- [ ] For forced-colors or high-contrast sign-off, use the [Forced-colors manual QA note](forced_colors_manual_qa.md) to record the browser/mode, active-filter cue, sorted-header cue, resize focus, filter panel boundary, and pinned-column evidence.
- [ ] Confirm custom host app colors meet the application's contrast requirements.

## 17. Customization

- [ ] Run `bin/rails generate rails_table_preferences:views`.
- [ ] Edit the copied ERB partial and confirm the app uses it.
- [ ] Run `bin/rails generate rails_table_preferences:stylesheets`.
- [ ] Edit the copied CSS and confirm visual changes apply.
- [ ] Run `bin/rails generate rails_table_preferences:javascript`.
- [ ] Edit the copied Stimulus controller and confirm behavior changes apply.
- [ ] Confirm host app can skip JavaScript copying when providing its own controller.
- [ ] Confirm host app can skip stylesheet copying when providing its own CSS.

## 18. Browser and layout checks

- [ ] Check the screen in Chrome or Edge.
- [ ] Check the screen at a phone-like narrow viewport or narrow container.
- [ ] Check the screen with long Japanese labels.
- [ ] Check the screen with long table values.
- [ ] Confirm editor inputs do not overlap.
- [ ] At 320px, 375px, and 390px-equivalent widths or narrow containers, confirm editor row labels wrap above the numeric controls and each order/width/truncate input keeps a usable tap and keyboard target.
- [ ] Confirm filter panels are not clipped.
- [ ] Confirm short viewport filter panels keep Apply and Clear reachable through panel scrolling.
- [ ] Confirm column width controls remain usable.
- [ ] Confirm editor order inputs remain reachable and readable at narrow widths.
- [ ] On a touch device or touch emulator, confirm table-header drag is not the only practical reorder path because the editor order input still works.
- [ ] Confirm resize handle hover/focus affordance does not collide with header text, filter buttons, sort indicators, or long labels.
- [ ] Confirm table operation hit areas do not interfere with normal table links/buttons.

## 19. Regression checklist from early implementation issues

- [ ] Column width changes apply to the table, not to editor cards.
- [ ] Editor row card widths do not unexpectedly mirror table column widths.
- [ ] Filter panel appears above surrounding content and is not clipped.
- [ ] The settings dialog/editor remains visible after CSS changes.
- [ ] Table drag, resize, filter, and sort interactions do not block each other.
- [ ] Saved filter/sort state survives editor apply operations.
- [ ] Current column metadata overrides stale saved metadata for labels, overflow modes, filters, sortable state, and pinned/fixed state after apply, save, reload, and reset flows.

## Sign-off

Use a short sign-off note for release candidates, host-app launch checks, or any run where skipped areas could affect the next reviewer. Keep the note compact: it should say what was checked, what was skipped, why it was skipped, and where follow-up work lives.

```markdown
### Manual QA sign-off

- Date:
- Tester:
- Build, branch, or PR:
- Environment:
- Screen or workflow checked:
- Checklist scope completed:
- Skipped areas and reasons:
- Issues found:
- Follow-up Issue / PR links:
- Release or rollout recommendation:
```

For a quick smoke, record the quick smoke items that passed and the specific full-checklist sections you did not run. For full release or host-app launch sign-off, note any skipped section by number and include the risk or reason, such as not using Ransack, not testing exports in that host app, or deferring browser coverage to a separate compatibility pass.
