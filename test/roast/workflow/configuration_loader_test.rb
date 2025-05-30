# frozen_string_literal: true

require "test_helper"
require "roast/workflow/configuration_loader"
require "tempfile"

module Roast
  module Workflow
    class ConfigurationLoaderTest < Minitest::Test
      def setup
        @valid_config = {
          "name" => "test-workflow",
          "steps" => ["step1", "step2"],
          "tools" => ["Roast::Tools::Grep"],
          "functions" => { "grep" => { "enabled" => true } },
          "model" => "gpt-4",
          "target" => "test.rb",
        }
      end

      def test_load_valid_yaml_file
        with_temp_yaml_file(@valid_config) do |path|
          config = ConfigurationLoader.load(path)
          assert_equal(@valid_config, config)
        end
      end

      def test_load_raises_on_nil_path
        error = assert_raises(ArgumentError) do
          ConfigurationLoader.load(nil)
        end
        assert_equal("Workflow path cannot be nil", error.message)
      end

      def test_load_raises_on_nonexistent_file
        error = assert_raises(ArgumentError) do
          ConfigurationLoader.load("/nonexistent/file.yml")
        end
        assert_match(/Workflow file not found/, error.message)
      end

      def test_load_raises_on_non_yaml_file
        with_temp_file("test.txt", "content") do |path|
          error = assert_raises(ArgumentError) do
            ConfigurationLoader.load(path)
          end
          assert_equal("Workflow path must be a YAML file", error.message)
        end
      end

      def test_load_accepts_yaml_extension
        with_temp_file("test.yaml", YAML.dump(@valid_config)) do |path|
          config = ConfigurationLoader.load(path)
          assert_equal(@valid_config, config)
        end
      end

      def test_extract_name_from_config
        name = ConfigurationLoader.extract_name(@valid_config, "workflow.yml")
        assert_equal("test-workflow", name)
      end

      def test_extract_name_from_filename_when_not_in_config
        config = @valid_config.dup
        config.delete("name")
        name = ConfigurationLoader.extract_name(config, "/path/to/my-workflow.yml")
        assert_equal("my-workflow", name)
      end

      def test_extract_steps
        steps = ConfigurationLoader.extract_steps(@valid_config)
        assert_equal(["step1", "step2"], steps)
      end

      def test_extract_steps_returns_empty_array_when_missing
        steps = ConfigurationLoader.extract_steps({})
        assert_equal([], steps)
      end

      def test_extract_tools
        tools = ConfigurationLoader.extract_tools(@valid_config)
        assert_equal(["Roast::Tools::Grep"], tools)
      end

      def test_extract_tools_returns_empty_array_when_missing
        tools = ConfigurationLoader.extract_tools({})
        assert_equal([], tools)
      end

      def test_extract_functions
        functions = ConfigurationLoader.extract_functions(@valid_config)
        assert_equal({ "grep" => { "enabled" => true } }, functions)
      end

      def test_extract_functions_returns_empty_hash_when_missing
        functions = ConfigurationLoader.extract_functions({})
        assert_equal({}, functions)
      end

      def test_extract_model
        model = ConfigurationLoader.extract_model(@valid_config)
        assert_equal("gpt-4", model)
      end

      def test_extract_model_returns_nil_when_missing
        assert_nil(ConfigurationLoader.extract_model({}))
      end

      def test_extract_target_from_config
        target = ConfigurationLoader.extract_target(@valid_config)
        assert_equal("test.rb", target)
      end

      def test_extract_target_from_options
        options = { target: "options.rb" }
        target = ConfigurationLoader.extract_target(@valid_config, options)
        assert_equal("options.rb", target)
      end

      def test_extract_target_prefers_options_over_config
        options = { target: "options.rb" }
        target = ConfigurationLoader.extract_target(@valid_config, options)
        assert_equal("options.rb", target)
      end

      def test_load_with_shared_yml
        shared_yaml = <<~YAML
          standard_tools: &tools
            - "Roast::Tools::Grep"
            - "Roast::Tools::ReadFile"
        YAML

        workflow_yaml = <<~YAML
          name: "test-workflow"
          api_token: "test-token"
          model: "gpt-4"
          tools: *tools
          steps: ["step1", "step2"]
        YAML

        with_temp_workflow_and_shared_yaml(workflow_yaml, shared_yaml) do |workflow_path|
          config = ConfigurationLoader.load(workflow_path)

          assert_equal("test-workflow", config["name"])
          assert_equal("test-token", config["api_token"])
          assert_equal("gpt-4", config["model"])
          assert_equal(["Roast::Tools::Grep", "Roast::Tools::ReadFile"], config["tools"])
          assert_equal(["step1", "step2"], config["steps"])
        end
      end

      def test_load_without_shared_yml
        # Ensure it still works when shared.yml doesn't exist
        workflow_config = {
          "name" => "test-workflow",
          "api_token" => "direct-token",
          "steps" => ["step1", "step2"],
        }

        with_temp_dir do |dir|
          subdir = File.join(dir, "workflows")
          FileUtils.mkdir_p(subdir)
          workflow_path = File.join(subdir, "workflow.yml")
          File.write(workflow_path, YAML.dump(workflow_config))

          config = ConfigurationLoader.load(workflow_path)

          assert_equal("test-workflow", config["name"])
          assert_equal("direct-token", config["api_token"])
          assert_equal(["step1", "step2"], config["steps"])
        end
      end

      def test_yaml_aliases_with_array_references
        shared_yaml = <<~YAML
          standard_tools: &tools
            - Roast::Tools::Grep
            - Roast::Tools::ReadFile
            - Roast::Tools::SearchFile
        YAML

        workflow_yaml = <<~YAML
          name: test-workflow
          tools: *tools
          steps:
            - step1
        YAML

        with_temp_workflow_and_shared_yaml(workflow_yaml, shared_yaml) do |workflow_path|
          config = ConfigurationLoader.load(workflow_path)

          assert_equal(["Roast::Tools::Grep", "Roast::Tools::ReadFile", "Roast::Tools::SearchFile"], config["tools"])
        end
      end

      private

      def with_temp_yaml_file(content)
        file = Tempfile.new(["workflow", ".yml"])
        file.write(YAML.dump(content))
        file.close
        yield file.path
      ensure
        file.unlink
      end

      def with_temp_file(filename, content)
        dir = Dir.mktmpdir
        path = File.join(dir, filename)
        File.write(path, content)
        yield path
      ensure
        FileUtils.rm_rf(dir)
      end

      def with_temp_dir
        dir = Dir.mktmpdir
        yield dir
      ensure
        FileUtils.rm_rf(dir)
      end

      def with_temp_workflow_and_shared_yaml(workflow_yaml, shared_yaml)
        dir = Dir.mktmpdir

        # Create shared.yml in parent directory
        File.write(File.join(dir, "shared.yml"), shared_yaml)

        # Create workflow subdirectory
        workflow_dir = File.join(dir, "workflows")
        FileUtils.mkdir_p(workflow_dir)

        # Create workflow.yml in subdirectory
        workflow_path = File.join(workflow_dir, "workflow.yml")
        File.write(workflow_path, workflow_yaml)

        yield workflow_path
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end
