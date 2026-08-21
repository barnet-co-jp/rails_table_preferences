import { Controller } from "@hotwired/stimulus"

export type RailsTablePreferencesLifecycleEvent = "applied" | "saved" | "loaded" | "deleted" | "state-changed" | "error"
export type RailsTablePreferencesEventName = `rails-table-preferences:${RailsTablePreferencesLifecycleEvent}`

export type RailsTablePreferencesSuccessAction = "apply" | "reset" | "save" | "create" | "load" | "delete" | "clear-filters-and-sorts"
export type RailsTablePreferencesStateChangeAction = "sort-change" | "filter-change" | "filter-clear"
export type RailsTablePreferencesErrorAction = RailsTablePreferencesSuccessAction | "load-presets" | "operation"
export type RailsTablePreferencesLifecycleAction = RailsTablePreferencesSuccessAction | RailsTablePreferencesStateChangeAction | RailsTablePreferencesErrorAction

export interface RailsTablePreferencesColumnGroupSnapshot {
  key?: string | number | null
  label?: string | null
  [key: string]: unknown
}

export interface RailsTablePreferencesFilterSnapshot {
  type?: string
  param?: string
  from_param?: string
  to_param?: string
  operator?: string
  value?: unknown
  values?: unknown[]
  options?: unknown[]
  [key: string]: unknown
}

export interface RailsTablePreferencesSortSnapshot {
  key: string
  direction?: string
  [key: string]: unknown
}

export interface RailsTablePreferencesColumnSnapshot {
  key: string
  export_key?: string
  label?: string
  visible?: boolean
  order?: number
  width?: number
  truncate?: number | boolean
  overflow?: string
  pinned?: boolean
  group?: string | RailsTablePreferencesColumnGroupSnapshot | null
  ignored?: boolean
  filter?: RailsTablePreferencesFilterSnapshot | null
  sortable?: boolean
  sort_param?: string
  [key: string]: unknown
}

export interface RailsTablePreferencesSettingsSnapshot {
  columns?: RailsTablePreferencesColumnSnapshot[]
  filters?: Record<string, RailsTablePreferencesFilterSnapshot | unknown>
  sorts?: RailsTablePreferencesSortSnapshot[]
  [key: string]: unknown
}

export interface RailsTablePreferencesEventDetailBase {
  tableKey: string
  name: string
  settings: RailsTablePreferencesSettingsSnapshot
}

export type RailsTablePreferencesSuccessEventDetail = RailsTablePreferencesEventDetailBase & {
  action: RailsTablePreferencesSuccessAction
}

export type RailsTablePreferencesStateChangedEventDetail = RailsTablePreferencesEventDetailBase & {
  action: RailsTablePreferencesStateChangeAction
}

export type RailsTablePreferencesErrorEventDetail = RailsTablePreferencesEventDetailBase & {
  action: RailsTablePreferencesErrorAction
  message: string
}

export interface RailsTablePreferencesEventDetailMap {
  "rails-table-preferences:applied": RailsTablePreferencesSuccessEventDetail
  "rails-table-preferences:saved": RailsTablePreferencesSuccessEventDetail
  "rails-table-preferences:loaded": RailsTablePreferencesSuccessEventDetail
  "rails-table-preferences:deleted": RailsTablePreferencesSuccessEventDetail
  "rails-table-preferences:state-changed": RailsTablePreferencesStateChangedEventDetail
  "rails-table-preferences:error": RailsTablePreferencesErrorEventDetail
}

export type RailsTablePreferencesEventDetailFor<EventName extends RailsTablePreferencesEventName> = RailsTablePreferencesEventDetailMap[EventName]

export type RailsTablePreferencesEventDetail = RailsTablePreferencesSuccessEventDetail | RailsTablePreferencesStateChangedEventDetail | RailsTablePreferencesErrorEventDetail

declare const RailsTablePreferencesController: typeof Controller
export default RailsTablePreferencesController
