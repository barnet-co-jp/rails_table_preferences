# frozen_string_literal: true

RSpec.describe "rails_table_preferences select filter option search source" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:controller_source) { File.read(File.join(repo_root, "app/javascript/rails_table_preferences/controller.js")).gsub(/\r\n?/, "\n") }

  it "keeps selected options visible while hiding only unmatched unselected options" do
    method_source = controller_source.match(
      /  filterSelectOptionsBySearch\(input, select, emptyMessage = null\) \{(?<body>[\s\S]*?)\n  \}\n\n  selectFilterOptionValue/
    )&.[](:body)

    expect(method_source).to include("const query = String(input?.value || \"\").trim().toLocaleLowerCase()")
    expect(method_source).to include("let matchingOptions = 0")
    expect(method_source).to include("const searchableText = `${option.textContent || \"\"} ${option.value || \"\"}`.toLocaleLowerCase()")
    expect(method_source).to include("const matchesQuery = searchableText.includes(query)")
    expect(method_source).to include("if (matchesQuery) matchingOptions += 1")
    expect(method_source).to include("option.hidden = Boolean(query) && !option.selected && !matchesQuery")
    expect(method_source).to include("if (emptyMessage) emptyMessage.hidden = !query || matchingOptions > 0")
    expect(method_source).not_to include("matchingUnselectedOptions")
  end
end
