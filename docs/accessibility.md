# Accessibility baseline

Rails Table Preferences aims to provide a practical accessibility baseline for server-rendered Rails tables.

This document explains what the gem provides and what the host application still owns.

## What the gem provides

The bundled editor and Stimulus controller provide:

- button elements for interactive controls
- labels for generated editor inputs
- configurable Japanese default labels
- a visible editor title rendered as a heading and connected to the editor root with `aria-labelledby` / `role="region"`, using per-editor ids so multiple editors on one page do not collide
- localized fallback scope labels for preset options when the payload does not provide `scope_label`
- `aria-label` for drag handles, resize handles, and filter buttons
- `aria-pressed` and `aria-expanded` for filter buttons
- `aria-controls` from the open filter button to the current filter panel
- `aria-sort` for sortable table headers
- disabled states for controls that should not be used on read-only scoped presets
- a visible helper message that explains the difference between the bundled `適用`, `保存`, and `別名で保存` actions
- per-field helper copy and `aria-describedby` context for the bundled preset selector and preset name field so users can tell which saved preset will load and which name save or save as new will use
- per-button `title` and `aria-label` text on the bundled `適用`, `保存`, and `別名で保存` buttons so users can tell whether they are applying the current editor state, saving to the current preset name, or creating a separately named preset
- a visible helper message when saving from a read-only preset will create or update the owner preset path instead of overwriting the shared preset directly
- a visible helper message and `aria-describedby` context for the bundled default preset checkbox so users can tell it only takes effect when they save or save as new
- a live `role="status"` region for bundled save/load/delete feedback and package-entrypoint reset, visibility bulk, and resize auto-fit success feedback
- a visible helper message plus explanatory `title`, `aria-label`, and `aria-describedby` text on the bundled reset button so users can tell it discards unsaved editor changes and returns to the default settings without relying only on hover text
- visible maintenance helper copy for delete/reset actions, with `aria-describedby` context on the maintenance group and delete/reset buttons
- temporary busy-state disabling for preset controls, generated editor inputs, and bundled header buttons while bundled async preset actions are running
- keyboard-focusable buttons and inputs through native HTML elements
- per-editor ids for the preset select and preset name fields so multiple editors on one page do not collide; the bundled partial generates those ids automatically for each rendered instance, and copied/customized views should preserve the label/input pairing while keeping ids unique
- optional semantic table captions for the default `resource_table_for` and `tree_resource_table_for` partials when the host app passes `caption:`
- package-entrypoint-only column search and row move buttons with accessible labels, plus disabled states for hidden, first, last, and busy rows
- package-entrypoint-only Enter/Space auto-fit on focused resize handles, matching the existing double-click auto-fit shortcut without adding full keyboard width adjustment

## Sortable headers

Sortable headers receive `aria-sort`:

```html
<th data-rails-table-preferences-column-key="delivery_date" aria-sort="ascending">
  納品日
</th>
```

The controller adds `aria-sort` only to the primary sorted header and updates it as that direction changes:

- `ascending`
- `descending`

When Shift-modified sorting adds secondary columns, every active sorted header receives `aria-description="並び替え優先順位: N"`, while visible `▲` / `▼` indicators remain on each sorted column. Keeping `aria-sort` on only the primary header avoids exposing multiple current sort headers; the priority description communicates the ordered multi-sort state.

## Filter buttons

Filter buttons receive an `aria-label`, `aria-pressed`, and `aria-expanded`:

```html
<button
  type="button"
  class="rails-table-preferences-filter-button"
  aria-label="絞り込み: 得意先名 (含む: ACME)"
  aria-pressed="true"
  aria-expanded="true"
  aria-controls="rails-table-preferences-filter-panel-orders_index-customer_name"
  title="絞り込み: 得意先名 (含む: ACME)">
  ▾
</button>
```

The pressed state reflects whether a filter condition is currently active for that column.

When a bundled filter is active, the button keeps its compact `▾` text but updates `title` and `aria-label` with a short operator/value summary so screen reader users and hover users can tell which condition is attached to that column without opening the panel again.

When a bundled filter panel opens, the controller moves focus into the panel, supports `Escape` to close it, and returns focus to the triggering filter button for that keyboard dismissal path. To avoid detached floating UI, the bundled panel also closes on scroll or viewport resize instead of trying to stay open at a stale position.

## Resize handles

Resize handles are generated as buttons and receive an `aria-label`:

```html
<button
  type="button"
  class="rails-table-preferences-resize-handle"
  aria-label="列幅を変更: 得意先名">
</button>
```

The bundled controller prefers the configured column label for that accessible name, falls back to the visible header text when needed, and only uses the raw column key when neither user-facing label is available.

The default resize behavior remains pointer-oriented. When the host app imports the packaged `rails_table_preferences/controller` entrypoint, a focused resize handle also accepts Enter or Space for the same one-shot auto-fit behavior as double-click. That shortcut is only an auto-fit affordance; it is not full keyboard width adjustment.

The package entrypoint reports that one-shot auto-fit success through the existing status region using `rails_table_preferences.editor.resize_auto_fit_status`. This is success feedback for the packaged shortcut, not a promise that the copied/base controller path has the same keyboard shortcut or status message unless the host app ports that behavior.

Full keyboard resizing would need additional product decisions such as arrow-key bindings, step size, min/max width feedback, cancellation behavior, and status announcements. Host applications that need that level of keyboard width editing should provide a custom controller or additional shortcuts, then verify the focus model and announcements in their own table layout.

## Resource table captions

When the host app uses the default `resource_table_for` or `tree_resource_table_for` partial, it can pass `caption:` to render a native `<caption>` immediately under the generated `<table>`:

```erb
<%= resource_table_for @orders, caption: "Orders" %>
<%= tree_resource_table_for @projects, caption: "Projects" %>
```

Use this for a short semantic table name that helps users distinguish the table surface. The caption is optional and only appears when the host app passes it.

Prefer captions that stay true as filters, pagination, or saved column visibility change. They are most useful when the page has more than one table, when the table heading is not immediately adjacent, or when the host app wants a compact accessible name for the generated table surface without copying the partial.

Rails Table Preferences does not try to generate page-level explanations, complex table summaries, or business-specific instructions. Keep those in the host application around the generated table, or use a custom partial when the caption needs richer markup than the default surface provides.

## Drag and drop

The default column reorder behavior uses native drag and drop for editor rows and table headers. Treat those drag affordances as pointer-oriented shortcuts, not as the only supported reorder path.

The bundled editor also exposes numeric order inputs. Keyboard-only users can change a column's order number, move to the bundled `適用` action, and apply the editor state without relying on drag and drop. This is the bundled keyboard-friendly fallback for reordering, not a resize keyboard fallback.

When a host application imports the packaged `rails_table_preferences/controller` entrypoint, the editor also renders labelled column-search and row up/down controls around the generated rows. These controls are additive to the numeric order fallback: filtered-out rows stay in the DOM so apply/save still keeps every column, row movement is limited to visible filtered rows, and generated move buttons disable for hidden rows, first/last visible rows, and async busy state.

For touch and narrow-viewport checks, do not assume table-header drag is the primary guaranteed path. Confirm the editor order inputs remain reachable and that applying those values updates the table order. Host applications that need stronger touch reordering, up/down controls, or full keyboard shortcuts should add those controls in a copied/custom controller rather than treating the bundled drag handles as a complete reorder design system.

## Read-only scoped presets

Shared, role, and organization presets may be returned as `editable: false`.

The bundled controller disables destructive/default controls for read-only presets, shows a short helper message about the save fallback, and falls back to creating or updating an owner preset when users save edits from the normal editor path.

This prevents the regular user-facing editor from accidentally overwriting shared presets while keeping the next action understandable.

## Status region and busy state

The bundled editor now includes a lightweight status region for the main async preset actions and package-entrypoint reset, visibility bulk, and resize auto-fit feedback:

- loading saved settings
- saving the current settings
- saving as a new preset
- deleting the current preset
- reporting action-specific failure copy when load, save, save as new, or delete cannot complete
- reporting package-entrypoint reset success after the bundled reset action returns the editor and table to the current column-definition defaults
- reporting package-entrypoint Show all columns / Hide all columns success after the bulk checkbox update completes
- reporting package-entrypoint Enter / Space auto-fit success after a focused resize handle uses the one-shot auto-fit shortcut

The default markup uses a native live region:

```html
<div
  class="rails-table-preferences-editor__status"
  role="status"
  aria-live="polite"
  aria-atomic="true">
</div>
```

When the host app imports the packaged `rails_table_preferences/controller` entrypoint, that same status target also receives `data-rails-table-preferences-status-state`. Treat this as a light styling and QA hook for the packaged controller path, not as a separate notification framework or lifecycle-event payload.

The packaged controller uses these values:

- `idle`: no current status message is shown, including after a successful message is cleared by a local editor change.
- `busy`: a bundled async preset action is loading, saving, saving as new, or deleting.
- `success`: a bundled async action completed successfully, or package-entrypoint reset, visibility bulk, or resize auto-fit reported success.
- `error`: load, save, save as new, delete, or initial preset-list loading failed; the error status stays visible until a later successful status or explicit clear.

The copied/base controller path should not rely on this data hook unless the host app ports the packaged status-state behavior into its copied or replacement controller. Host applications that need richer inline messaging, toast notifications, or custom state names should keep that behavior in their copied ERB, copied JavaScript, or host-app notification layer.

While those bundled async actions are in flight, the preset select, preset name, default checkbox, action buttons, generated editor row inputs, and bundled header buttons are temporarily disabled.

The controller also ignores bundled row drag, header drag, sort, filter, and resize interactions while the async request is still in flight. This keeps the visible table state from drifting away from the payload that is currently being loaded, saved, created, or deleted.

Host applications can still replace or restyle this surface through the existing copy-based customization path when they need richer inline messaging or branded notifications.

## Locale overrides for bundled copy

The current bundled helper and status copy is I18n-driven, so host applications can change wording without copying ERB or JavaScript when the existing structure is still acceptable.

Representative locale keys include:

- `rails_table_preferences.editor.action_hint`
- `rails_table_preferences.editor.maintenance_hint`
- `rails_table_preferences.editor.read_only_preset_hint`
- `rails_table_preferences.editor.loading_status`
- `rails_table_preferences.editor.saved_status`
- `rails_table_preferences.editor.deleting_failed_status`
- `rails_table_preferences.editor.reset_status`
- `rails_table_preferences.editor.resize_auto_fit_status`
- `rails_table_preferences.editor.reset_hint`
- `rails_table_preferences.editor.reset_visible_hint`

Those keys feed different bundled accessibility surfaces:

- `action_hint`: the visible helper text and `aria-describedby` context for `適用`, `保存`, and `別名で保存`
- `maintenance_hint`: the visible helper text and `aria-describedby` context for delete/reset maintenance actions
- `read_only_preset_hint`: the helper text shown when a shared, role, or organization preset is read-only
- `*_status`: the live `role="status"` region used for async preset feedback
- `reset_status`: the same live status region after package-entrypoint reset restores current column-definition defaults
- `resize_auto_fit_status`: the same live status region after package-entrypoint Enter / Space auto-fit on a focused resize handle
- `reset_hint`: the bundled reset button `title` and `aria-label`
- `reset_visible_hint`: the visible helper text and `aria-describedby` context for the bundled reset button

## Choosing the copy override path

Use the lightest override that matches the wording change you need.

### 1. Locale keys for bundled helper and status copy

Use locale entries when the text is already rendered in the bundled ERB partial and the existing markup is still acceptable.

Typical locale-driven surfaces include:

- preset selector and preset name helper text
- action hint copy for `適用`, `保存`, and `別名で保存`
- maintenance hint copy for delete/reset action context
- read-only preset helper text
- reset visible helper and button wording
- async status-region progress, success, and failure copy
- package-entrypoint reset, visibility bulk, and resize auto-fit success copy

This is the best default when the same wording should stay consistent across every screen that uses the bundled editor.

### 2. Stimulus values for per-root filter, sort, or scope wording

Use controller-root values when the copy belongs to the bundled controller surface itself or when one table needs wording that differs from another.

Representative attributes include:

- `data-rails-table-preferences-filter-label-value`
- `data-rails-table-preferences-filter-apply-label-value`
- `data-rails-table-preferences-filter-clear-label-value`
- `data-rails-table-preferences-filter-operator-label-value`
- `data-rails-table-preferences-filter-operator-labels-value`
- `data-rails-table-preferences-filter-value-label-value`
- `data-rails-table-preferences-filter-from-label-value`
- `data-rails-table-preferences-filter-to-label-value`
- `data-rails-table-preferences-sort-asc-label-value`
- `data-rails-table-preferences-sort-desc-label-value`
- `data-rails-table-preferences-sort-clear-label-value`
- `data-rails-table-preferences-scope-owner-label-value`
- `data-rails-table-preferences-scope-shared-label-value`
- `data-rails-table-preferences-scope-role-label-value`
- `data-rails-table-preferences-scope-organization-label-value`

These values affect controller-owned text such as filter button `aria-label` / `title`, bundled filter panel field labels, sort announcements, operator option labels and active-filter summaries, and scope fallback labels for preset options. The bundled helper output already passes default values from I18n, but host apps can override a single controller root when a specific screen needs different wording.

The `data-rails-table-preferences-filter-operator-labels-value` attribute is a JSON object supported by the packaged `rails_table_preferences/controller` entrypoint. Keys are operator names such as `contains` or `equals`, and values are the labels shown in the bundled filter panel and active-filter summary. Host apps that use a copied base controller directly should not assume this package entrypoint-only value is available. For the controller-side contract, see [JavaScript controller notes](javascript_controller.md).

### 3. Copied ERB or copied JavaScript for markup or logic changes

Copy the bundled ERB partial when the host app needs different markup or helper-text placement, such as:

- a custom status surface instead of the bundled `role="status"` block
- extra screen-specific helper copy around preset controls
- different button layout or additional descriptive markup

Copy or replace the bundled JavaScript when the host app needs controller logic or vocabulary that is not exposed through root values, such as:

- new filter operator semantics or operator display rules beyond `filterOperatorLabels`
- different busy-state or status-update behavior
- custom filter panel interaction rules
- extra confirmation flow beyond the bundled delete confirm

In other words, changing `絞り込み`, `条件`, `開始`, `終了`, scope fallback labels, or packaged-controller operator labels can stay in locale entries and root values. Changing operator behavior, adding new operator semantics, or using a controller path that does not include the package entrypoint subclass still requires copied JavaScript today.

Minimal host-app override example:

```yaml
ja:
  rails_table_preferences:
    editor:
      action_hint: 適用は現在の表示だけを更新し、保存は現在の設定名へ反映、別名で保存は新しい設定として残します。
      maintenance_hint: 削除とリセットは保存済み設定や現在の編集内容に影響するため、内容を確認してから実行してください。
      read_only_preset_hint: この設定は直接更新できません。保存すると個人用設定として保存されます。
      loading_status: 設定を読み込み中です...
      saved_status: 設定を保存しました。
      deleting_failed_status: 設定の削除を完了できませんでした。
      resize_auto_fit_status: 列幅を自動調整しました。
      reset_hint: 保存前の変更を破棄して初期表示へ戻します。
      reset_visible_hint: 初期状態に戻すと、保存前の変更は破棄されます。
```

If the host app also needs per-screen wording, different markup, or a custom status surface, keep using the existing copy-based path by copying the bundled ERB partial or controller.

## Forced-colors and high contrast checks

The bundled CSS intentionally relies on lightweight system-friendly values such as `currentColor`, `canvas`, and `canvastext`. That keeps the default surface adaptable, but host applications should still verify the final rendered table in the application's high contrast or forced-colors mode.

Use [Forced-colors manual QA note](forced_colors_manual_qa.md) when a design or accessibility review needs a focused browser handoff checklist for active filters, sorted headers, resize focus, filter panel boundaries, and pinned or fixed column backgrounds.

When checking a release candidate or host-app rollout, confirm the representative table still exposes these states without relying on color alone:

- active filter buttons remain distinguishable from inactive filter buttons through the accessible name, pressed state, and visible affordance
- sorted headers keep `aria-sort` and a visible sorted-state cue
- focused resize handles have a visible focus outline and remain reachable near filter and sort controls
- the open filter panel container remains visually separate from the table background and surrounding app chrome
- pinned or fixed columns keep an opaque background and do not hide focused links, buttons, inputs, or filter controls while horizontally scrolled

If the host app's theme makes one of those states ambiguous in forced-colors mode, prefer the smallest host-app or copied-stylesheet adjustment that restores the state cue. Do not treat the bundled gem CSS as a full design-system high contrast theme for every host application.

## Host application responsibilities

The host application owns:

- semantic table markup beyond the default resource table caption surface
- page-level headings and instructions
- complex table captions, explanatory copy, and custom partial layouts
- focus order around surrounding UI
- color contrast after applying app-specific styles
- keyboard behavior beyond native form controls, the bundled order-input reorder fallback, and the packaged resize auto-fit shortcut
- full keyboard width adjustment for resize handles, including key bindings, step size, live feedback, and status announcements
- custom confirmation dialogs
- authorization messaging
- testing with the application's real design system

## Manual checks

Before releasing a screen, check:

- All editor controls can receive focus.
- Focus order is understandable.
- The editor root is announced as a named region using the visible editor heading, and multiple editors on one page do not reuse the same title id.
- The preset select, preset name, default checkbox, action buttons, and status region are labeled.
- The bundled action hint or accessible names explain the difference between apply, save, and save as new.
- The preset selector helper copy or accessible description explains that it loads or switches the saved preset rather than setting the save target name.
- The preset name helper copy or accessible description explains that save and save as new use that field as the edited preset name.
- The default checkbox helper text or accessible description explains that it only takes effect when the user saves or save as new.
- The reset visible helper, hover text, and accessible name explain that current edits are discarded and defaults are restored.
- The maintenance action group and delete/reset buttons keep visible helper text or accessible descriptions that explain the impact of those actions.
- At 36rem and 26rem-equivalent widths or narrow containers, the action row wraps without clipping, the delete/reset maintenance group stays visually separated from save actions, and helper text does not overlap buttons or editor controls.
- Sortable headers expose the current sort state.
- Active filters expose an active pressed state.
- Active filter buttons expose a short operator/value summary through `title` or `aria-label`.
- Filter buttons expose expanded state only while their panel is open.
- Opening a filter panel moves focus into the first bundled field.
- `Escape` closes the bundled filter panel and returns focus to the triggering filter button.
- Scroll or viewport resize does not leave the bundled filter panel detached from its header context.
- Read-only scoped presets disable destructive/default controls.
- Read-only scoped presets show helper text that explains the save fallback goes to the owner preset path without implying it always creates a brand-new preset.
- Save/load/delete actions update the status region with understandable progress, result, and action-specific failure copy.
- Async preset actions temporarily disable controls and re-enable them after completion.
- Async preset actions keep editor row inputs, drag handles, filter buttons, resize handles, and sortable headers from changing state until the request finishes.
- When using the packaged `rails_table_preferences/controller` entrypoint, the column search input has a visible label or accessible name, filtered-out rows are not dropped from apply/save settings, row up/down buttons announce the configured move labels, and hidden/first/last/busy move-button states are disabled.
- When using the packaged entrypoint at 320px, 375px, and 390px-equivalent widths or narrow containers, the column search and row move buttons remain reachable without overlapping labels, numeric order inputs, width inputs, or truncate inputs.
- Resource table captions are present when a short semantic table name is needed, and they do not duplicate or replace the page heading or surrounding instructions.
- Resize handles announce the user-facing column label rather than only an internal column key.
- Keyboard-only users can use Enter or Space on a focused resize handle for package-entrypoint auto-fit, but should not expect arrow-key or step-based width adjustment from the bundled controller.
- Package-entrypoint auto-fit updates the status region with the configured `resize_auto_fit_status` copy.
- Keyboard-only users can reorder columns through the editor order inputs and the bundled `適用` action without relying on drag and drop.
- Touch and narrow-viewport checks confirm the editor order inputs remain usable as the fallback when table-header drag is not comfortable or reliable.
- The table remains understandable when columns are hidden.
- Sticky/fixed columns do not cover focused content.
- Forced-colors or high contrast checks still leave active filters, sorted headers, focused resize handles, filter panel boundaries, and pinned columns distinguishable.
- Custom colors still meet the host application's contrast requirements.
- If the host app overrides bundled helper or status copy, the locale entries still match the intended action and accessibility context.

## Customization path

If the default behavior is not sufficient, use the existing copy-based customization path:

```bash
bin/rails generate rails_table_preferences:views
bin/rails generate rails_table_preferences:javascript
bin/rails generate rails_table_preferences:stylesheets
```

Then adjust the generated ERB, Stimulus controller, or CSS in the host application.
