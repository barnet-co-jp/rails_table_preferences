# frozen_string_literal: true

RSpec.describe "package state change lifecycle events" do
  let(:source_path) do
    File.expand_path("../../app/javascript/rails_table_preferences/preset_select_recovery.js", __dir__)
  end

  let(:source) { File.read(source_path) }

  it "dispatches state-changed only when sort or filter settings actually change" do
    expect(source).to include('this.dispatchPreferenceEvent("state-changed", { action })')
    expect(source).to include('this.dispatchStateChangedIfNeeded(previous, "sort-change")')
    expect(source).to include('this.dispatchStateChangedIfNeeded(previous, "filter-change")')
    expect(source).to include('this.dispatchStateChangedIfNeeded(previous, "filter-clear")')
    expect(source).to include("if (previousFingerprint === this.stateChangeFingerprint()) return")
  end

  it "keeps state change observation on the public package entrypoint layer" do
    expect(source).to include('import RailsTablePreferencesController from "./controller.js"')
    expect(source).to include("export default class RailsTablePreferencesPresetSelectRecoveryController extends RailsTablePreferencesController")
  end
end
