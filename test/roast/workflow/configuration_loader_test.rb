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
        tools, tool_configs = ConfigurationLoader.extract_tools(@valid_config)
        assert_equal(["Roast::Tools::Grep"], tools)
        assert_equal({}, tool_configs)
      end

      def test_extract_tools_returns_empty_array_when_missing
        tools, tool_configs = ConfigurationLoader.extract_tools({})
        assert_equal([], tools)
        assert_equal({}, tool_configs)
      end

      def test_extract_tools_with_mixed_formats
        config = {
          "tools" => [
            "Roast::Tools::Grep",
            { "Roast::Tools::Cmd" => { "allowed_commands" => ["ls", "pwd"] } },
            "Roast::Tools::ReadFile",
          ],
        }
        tools, tool_configs = ConfigurationLoader.extract_tools(config)

        assert_equal(["Roast::Tools::Grep", "Roast::Tools::Cmd", "Roast::Tools::ReadFile"], tools)
        assert_equal({ "Roast::Tools::Cmd" => { "allowed_commands" => ["ls", "pwd"] } }, tool_configs)
      end

      def test_extract_tools_with_only_hash_format
        config = {
          "tools" => [
            { "Roast::Tools::Cmd" => { "allowed_commands" => ["git"] } },
            { "Roast::Tools::Grep" => nil },
          ],
        }
        tools, tool_configs = ConfigurationLoader.extract_tools(config)

        assert_equal(["Roast::Tools::Cmd", "Roast::Tools::Grep"], tools)
        assert_equal(
          {
            "Roast::Tools::Cmd" => { "allowed_commands" => ["git"] },
            "Roast::Tools::Grep" => {},
          },
          tool_configs,
        )
      end

      def test_extract_tools_with_nil_config_in_hash
        config = {
          "tools" => [
            { "Roast::Tools::Cmd" => nil },
          ],
        }
        tools, tool_configs = ConfigurationLoader.extract_tools(config)

        assert_equal(["Roast::Tools::Cmd"], tools)
        assert_equal({ "Roast::Tools::Cmd" => {} }, tool_configs)
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
    end
  end
end
