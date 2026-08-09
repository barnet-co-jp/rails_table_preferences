# frozen_string_literal: true

RSpec.describe RailsTablePreferences::PackageVerifier do
  describe ".call" do
    it "reports success when all required paths are packaged" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[README.md CHANGELOG.md])
      allow(verifier).to receive(:packaged_files).and_return(%w[CHANGELOG.md README.md docs/index.md])

      result = verifier.call

      expect(result[:ok]).to eq(true)
      expect(result[:missing]).to eq([])
    end

    it "reports missing required paths" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[README.md CHANGELOG.md docs/index.md])
      allow(verifier).to receive(:packaged_files).and_return(%w[README.md])

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:missing]).to eq(%w[CHANGELOG.md docs/index.md])
    end

    it "reports success when package exports point to packaged JavaScript and declaration entrypoints" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[package.json])
      allow(verifier).to receive(:packaged_files).and_return(
        %w[
          app/javascript/controllers/rails_table_preferences_controller.js
          app/javascript/rails_table_preferences/controller.d.ts
          app/javascript/rails_table_preferences/controller.js
          app/javascript/rails_table_preferences/index.d.ts
          app/javascript/rails_table_preferences/index.js
          package.json
        ]
      )
      stub_packaged_file_contents(verifier)

      result = verifier.call

      expect(result[:ok]).to eq(true)
      expect(result[:missing_package_export_targets]).to eq([])
      expect(result[:missing_package_internal_imports]).to eq([])
      expect(result[:missing_package_declaration_imports]).to eq([])
      expect(result[:package_json_errors]).to eq([])
    end

    it "reports package exports that point to files missing from the built gem" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[package.json])
      allow(verifier).to receive(:packaged_files).and_return(
        %w[
          app/javascript/rails_table_preferences/index.js
          package.json
        ]
      )
      stub_packaged_file_contents(verifier)

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:missing]).to eq([])
      expect(result[:missing_package_export_targets]).to include(
        {
          export: "./controller",
          target: "app/javascript/rails_table_preferences/controller.js"
        }
      )
    end

    it "reports declaration re-export targets that are missing from the built gem" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[package.json])
      allow(verifier).to receive(:packaged_files).and_return(
        %w[
          app/javascript/controllers/rails_table_preferences_controller.js
          app/javascript/rails_table_preferences/controller.js
          app/javascript/rails_table_preferences/index.d.ts
          app/javascript/rails_table_preferences/index.js
          package.json
        ]
      )
      stub_packaged_file_contents(verifier)

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:missing_package_declaration_imports]).to eq(
        [
          {
            export: ".",
            entrypoint: "app/javascript/rails_table_preferences/index.d.ts",
            import: "./controller",
            target: "app/javascript/rails_table_preferences/controller"
          }
        ]
      )
    end

    it "reports invalid packaged package metadata" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[package.json])
      allow(verifier).to receive(:packaged_files).and_return(%w[package.json])
      allow(verifier).to receive(:packaged_file_contents).with("package.json").and_return("{")

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:package_json_errors].join).to include("package.json could not be parsed")
    end

    it "reports package metadata when resolver boundaries drift" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[package.json])
      allow(verifier).to receive(:packaged_files).and_return(%w[package.json])
      allow(verifier).to receive(:packaged_file_contents).with("package.json").and_return(
        {
          "private" => false,
          "version" => "1.2.3",
          "exports" => {}
        }.to_json
      )

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:package_json_errors]).to include(
        a_string_including("private must remain true"),
        a_string_including("version must remain 0.0.0")
      )
    end

    it "accepts gemspec metadata URLs that point to the repository entrypoints" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[README.md CHANGELOG.md docs/index.md])
      homepage = "https://github.com/barnet-co-jp/rails_table_preferences"
      allow(verifier).to receive(:package_spec).and_return(
        package_spec_double(
          files: %w[CHANGELOG.md README.md docs/index.md],
          homepage: homepage,
          metadata: {
            "homepage_uri" => homepage,
            "source_code_uri" => homepage,
            "changelog_uri" => "#{homepage}/blob/main/CHANGELOG.md",
            "documentation_uri" => "#{homepage}/blob/main/docs/index.md"
          }
        )
      )

      result = verifier.call

      expect(result[:ok]).to eq(true)
      expect(result[:gemspec_metadata_errors]).to eq([])
    end

    it "reports gemspec metadata URLs that drift from repository entrypoints" do
      verifier = described_class.new(gem_path: "dummy.gem", required_paths: %w[README.md CHANGELOG.md docs/index.md])
      homepage = "https://github.com/barnet-co-jp/rails_table_preferences"
      allow(verifier).to receive(:package_spec).and_return(
        package_spec_double(
          files: %w[CHANGELOG.md README.md docs/index.md],
          homepage: homepage,
          metadata: {
            "homepage_uri" => homepage,
            "source_code_uri" => homepage,
            "changelog_uri" => "#{homepage}/blob/main/docs/changelog.md",
            "documentation_uri" => "#{homepage}/blob/main/docs/README.md"
          }
        )
      )

      result = verifier.call

      expect(result[:ok]).to eq(false)
      expect(result[:gemspec_metadata_errors]).to include(
        "gemspec metadata changelog_uri must point to #{homepage}/blob/main/CHANGELOG.md (got \"#{homepage}/blob/main/docs/changelog.md\")",
        "gemspec metadata documentation_uri must point to #{homepage}/blob/main/docs/index.md (got \"#{homepage}/blob/main/docs/README.md\")"
      )
    end
  end

  describe ".summary" do
    it "counts missing declaration imports separately from JavaScript imports" do
      summary = described_class.summary(
        ok: false,
        missing: [],
        missing_package_export_targets: [],
        missing_package_internal_imports: [],
        missing_package_declaration_imports: ["app/javascript/rails_table_preferences/controller.d.ts"],
        package_json_errors: []
      )

      expect(summary).to include(ok: false, total: 1)
      expect(summary.fetch(:counts)).to include(missing_package_declaration_imports: 1)
    end
  end

  describe "required packaged runtime files" do
    it "keeps the legacy import task dependency in the package guard" do
      expect(described_class::REQUIRED_PATHS).to include(
        "lib/tasks/rails_table_preferences.rake",
        "lib/rails_table_preferences/legacy_column_adjustment_importer.rb"
      )
    end
  end

  describe "required packaged docs" do
    it "keeps the main README/docs index entrypoints in the package guard" do
      expected_docs = %w[
        docs/index.md
        docs/quick_start.md
        docs/quick_start_ja.md
        docs/install_paths.md
        docs/resource_tables.md
        docs/render_editor_placement_manual_qa.md
        docs/resource_table_cell_hooks.md
        docs/table_data_attributes.md
        docs/resource_table_formatter_contract.md
        docs/virtual_columns_query_boundary.md
        docs/decision_guide.md
        docs/scoped_presets.md
        docs/preset_selector_scope_labels.md
        docs/fixed_columns_and_groups.md
        docs/column_overflow.md
        docs/resize_auto_fit.md
        docs/export_integration.md
        docs/accessibility.md
        docs/editor_entrypoint_affordances.md
        docs/editor_reorder_accessibility.md
        docs/header_drag_reorder.md
        docs/editor_root_options.md
        docs/helper_free_controller_root_urls.md
        docs/visual_overview.md
        docs/demo.md
        docs/sandbox.md
        docs/examples.md
        docs/troubleshooting.md
        docs/manual_qa.md
        docs/release_checklist.md
        docs/package_verification.md
        docs/controller_integration.md
        docs/filter_metadata.md
        docs/filter_adapters.md
        docs/select_filter_troubleshooting.md
        docs/select_filter_option_search_threshold.md
        docs/javascript_entrypoints.md
        docs/javascript_controller.md
      ]

      expect(described_class::REQUIRED_PATHS).to include(*expected_docs)
    end
  end

  describe "required packaged locale files" do
    it "keeps the default English and Japanese locale files in the package guard" do
      expect(described_class::REQUIRED_PATHS).to include(
        "config/locales/en.yml",
        "config/locales/ja.yml"
      )
    end
  end

  def stub_packaged_file_contents(verifier)
    allow(verifier).to receive(:packaged_file_contents) do |path|
      case path
      when "package.json"
        package_json
      when "app/javascript/rails_table_preferences/index.js"
        "export { default } from \"./controller\"\n"
      when "app/javascript/rails_table_preferences/controller.js"
        "import RailsTablePreferencesBaseController from \"../controllers/rails_table_preferences_controller\"\n"
      when "app/javascript/rails_table_preferences/index.d.ts"
        "export { default, default as RailsTablePreferencesController } from \"./controller\"\n"
      when "app/javascript/rails_table_preferences/controller.d.ts"
        "export default class RailsTablePreferencesController {}\n"
      else
        raise KeyError, path
      end
    end
  end

  def package_spec_double(files:, homepage:, metadata: {})
    instance_double(Gem::Specification, files: files, homepage: homepage, metadata: metadata)
  end

  def package_json
    {
      "private" => true,
      "version" => "0.0.0",
      "exports" => {
        "." => {
          "types" => "./app/javascript/rails_table_preferences/index.d.ts",
          "default" => "./app/javascript/rails_table_preferences/index.js"
        },
        "./controller" => {
          "types" => "./app/javascript/rails_table_preferences/controller.d.ts",
          "default" => "./app/javascript/rails_table_preferences/controller.js"
        }
      }
    }.to_json
  end
end
