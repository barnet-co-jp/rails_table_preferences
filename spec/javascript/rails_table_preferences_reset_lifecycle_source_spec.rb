# frozen_string_literal: true

RSpec.describe "rails_table_preferences reset lifecycle event source" do
  let(:source_path) do
    File.expand_path("../../app/javascript/rails_table_preferences/controller.js", __dir__)
  end

  let(:source) { File.read(source_path).gsub(/\r\n?/, "\n") }

  it "keeps reset editor wired to the applied lifecycle event without dispatching while busy" do
    expect(source).to include("resetEditor(event)")
    expect(source).to include("const wasBusy = this.busy")
    expect(source).to include("const result = super.resetEditor(event)")
    expect(source).to include("this.clearEditorSearchQuery()")
    expect(source).to include("this.setStatus(this.resetStatusLabelValue, \"success\")")
    expect(source).to include('this.dispatchPreferenceEvent("applied", { action: "reset" })')
    expect(source).to match(/if \(!wasBusy\) \{\n\s+this\.clearEditorSearchQuery\(\)\n\s+this\.setStatus\(this\.resetStatusLabelValue, "success"\)\n\s+this\.syncResetButtonState\(\)\n\s+this\.dispatchPreferenceEvent\("applied", \{ action: "reset" \}\)\n\s+\}/)
  end
end
