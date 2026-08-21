# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rails_table_preferences TypeScript declarations" do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  def read_declaration(path)
    File.read(File.join(repo_root, "app/javascript/rails_table_preferences", path))
  end

  it "exports the lifecycle event detail type surface from package declarations" do
    controller_declaration = read_declaration("controller.d.ts")
    index_declaration = read_declaration("index.d.ts")

    expect(controller_declaration).to include(
      "export type RailsTablePreferencesLifecycleEvent",
      "\"applied\" | \"saved\" | \"loaded\" | \"deleted\" | \"state-changed\" | \"error\"",
      "export type RailsTablePreferencesEventName",
      "`rails-table-preferences:${RailsTablePreferencesLifecycleEvent}`",
      "export type RailsTablePreferencesSuccessAction",
      "\"apply\" | \"reset\" | \"save\" | \"create\" | \"load\" | \"delete\"",
      "export type RailsTablePreferencesErrorAction",
      "\"load-presets\" | \"operation\"",
      "export interface RailsTablePreferencesSettingsSnapshot",
      "export interface RailsTablePreferencesEventDetailMap",
      "\"rails-table-preferences:applied\": RailsTablePreferencesSuccessEventDetail",
      "\"rails-table-preferences:saved\": RailsTablePreferencesSuccessEventDetail",
      "\"rails-table-preferences:loaded\": RailsTablePreferencesSuccessEventDetail",
      "\"rails-table-preferences:deleted\": RailsTablePreferencesSuccessEventDetail",
      "\"rails-table-preferences:error\": RailsTablePreferencesErrorEventDetail",
      "export type RailsTablePreferencesEventDetailFor<EventName extends RailsTablePreferencesEventName>",
      "export type RailsTablePreferencesEventDetail"
    )

    expect(index_declaration).to include(
      "RailsTablePreferencesController",
      "RailsTablePreferencesEventDetail",
      "RailsTablePreferencesEventDetailFor",
      "RailsTablePreferencesEventDetailMap",
      "RailsTablePreferencesEventName",
      "RailsTablePreferencesSuccessAction",
      "RailsTablePreferencesErrorAction"
    )
  end

  it "exports settings snapshot helper types from package declarations" do
    controller_declaration = read_declaration("controller.d.ts")
    index_declaration = read_declaration("index.d.ts")

    expect(controller_declaration).to include(
      "export interface RailsTablePreferencesColumnSnapshot",
      "export interface RailsTablePreferencesColumnGroupSnapshot",
      "export interface RailsTablePreferencesFilterSnapshot",
      "export interface RailsTablePreferencesSortSnapshot",
      "columns?: RailsTablePreferencesColumnSnapshot[]",
      "filters?: Record<string, RailsTablePreferencesFilterSnapshot | unknown>",
      "sorts?: RailsTablePreferencesSortSnapshot[]"
    )

    expect(index_declaration).to include(
      "RailsTablePreferencesColumnSnapshot",
      "RailsTablePreferencesColumnGroupSnapshot",
      "RailsTablePreferencesFilterSnapshot",
      "RailsTablePreferencesSortSnapshot",
      "RailsTablePreferencesSettingsSnapshot"
    )
  end

  it "keeps lifecycle declarations focused on package event payloads" do
    controller_declaration = read_declaration("controller.d.ts")

    expect(controller_declaration).not_to include("handleOperationError")
    expect(controller_declaration).not_to include("withPreferenceAction")
    expect(controller_declaration).not_to include("dispatchPreferenceEvent")
    expect(controller_declaration).not_to include("rawError")
    expect(controller_declaration).not_to include("error: Error")
  end
end
