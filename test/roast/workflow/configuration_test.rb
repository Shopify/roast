# frozen_string_literal: true

require "test_helper"
require "roast/workflow/configuration"
require "yaml"
require "open3"
require "fileutils"
require "tempfile"

module Roast
  module Workflow
    class ConfigurationTest < ActiveSupport::TestCase
      FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

      def fixture_file(filename)
        File.join(FIXTURES, filename)
      end

      def setup
        @options = {}
        FileUtils.mkdir_p(FIXTURES) unless Dir.exist?(FIXTURES)
      end

      def test_initialize_loads_configuration_from_yaml_file
        configuration = Roast::Workflow::Configuration.new(fixture_file("valid_workflow.yml"), @options)
        assert_equal("My Workflow", configuration.name)
        assert_kind_of(Array, configuration.steps)
        assert_kind_of(Array, configuration.tools)
      end

      class TargetProvidedTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

        def fixture_file(filename)
          File.join(FIXTURES, filename)
        end

        def setup
          @options = {}
          FileUtils.mkdir_p(FIXTURES) unless Dir.exist?(FIXTURES)
        end

        def test_processes_shell_command_target
          workflow_path = fixture_file("workflow_with_shell_target.yml")
          # Simulate shell command output for $(echo test.rb)
          Open3.stub(:capture2e, ["test.rb\n", Minitest::Mock.new.expect(:success?, true)]) do
            configuration = Roast::Workflow::Configuration.new(workflow_path, @options)
            assert_equal(File.expand_path("test.rb"), configuration.target)
          end
        end

        def test_expands_glob_patterns
          workflow_path = fixture_file("workflow_with_glob_target.yml")
          # Simulate glob expansion
          Dir.stub(:glob, ["foo_spec.rb", "bar_spec.rb"]) do
            configuration = Roast::Workflow::Configuration.new(workflow_path, @options)
            assert_includes(configuration.target, "_spec.rb")
          end
        end
      end

      class ApiTokenProvidedTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

        def fixture_file(filename)
          File.join(FIXTURES, filename)
        end

        def setup
          @options = {}
          FileUtils.mkdir_p(FIXTURES) unless Dir.exist?(FIXTURES)
          @workflow_path = fixture_file("workflow_with_api_token.yml")
          @api_token_yaml = {
            "name" => "Workflow with API Token",
            "steps" => ["step1"],
            "api_token" => "$(echo test_token)",
          }.to_yaml
          File.write(@workflow_path, @api_token_yaml)
        end

        def teardown
          File.delete(@workflow_path) if File.exist?(@workflow_path)
        end

        def test_processes_shell_command_to_get_api_token
          # Simulate shell command output for $(echo test_token)
          Open3.stub(:capture2e, ["test_token\n", Minitest::Mock.new.expect(:success?, true)]) do
            configuration = Roast::Workflow::Configuration.new(@workflow_path, @options)
            assert_equal("test_token", configuration.api_token)
          end
        end
      end

      class FunctionConfigTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

        def fixture_file(filename)
          File.join(FIXTURES, filename)
        end

        def setup
          @options = {}
          FileUtils.mkdir_p(FIXTURES) unless Dir.exist?(FIXTURES)
          @workflow_path = fixture_file("workflow_with_functions.yml")
          @functions_yaml = {
            "name" => "Workflow with Functions",
            "steps" => ["step1"],
            "functions" => {
              "grep" => { "cache" => { "enabled" => true } },
            },
          }.to_yaml
          File.write(@workflow_path, @functions_yaml)
        end

        def teardown
          File.delete(@workflow_path) if File.exist?(@workflow_path)
        end

        def test_returns_configuration_for_existing_function
          configuration = Roast::Workflow::Configuration.new(@workflow_path, @options)
          assert_equal({ "cache" => { "enabled" => true } }, configuration.function_config("grep"))
        end

        def test_returns_empty_hash_for_non_existing_function
          configuration = Roast::Workflow::Configuration.new(@workflow_path, @options)
          assert_equal({}, configuration.function_config("nonexistent"))
        end
      end

      class ToolConfigTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

        def fixture_file(filename)
          File.join(FIXTURES, filename)
        end

        def setup
          @options = {}
          FileUtils.mkdir_p(FIXTURES) unless Dir.exist?(FIXTURES)
        end

        def teardown
          # Clean up any temporary files created during tests
          Dir.glob(File.join(FIXTURES, "*.yml")).each do |file|
            File.delete(file) if File.basename(file).start_with?("mixed_tools_config") ||
              File.basename(file).start_with?("string_tools_only") ||
              File.basename(file).start_with?("hash_tools_only") ||
              File.basename(file).start_with?("empty_tools")
          end
        end

        def test_parses_mixed_tool_formats_with_string_and_hash_configurations
          temp_file = Tempfile.new(["mixed_tools_config", ".yml"], FIXTURES)
          config_hash = {
            "name" => "Mixed Tools Test",
            "tools" => [
              "Roast::Tools::Grep",
              { "Roast::Tools::Cmd" => { "allowed_commands" => ["sed", "gh", "ruby"] } },
              "Roast::Tools::ReadFile",
              "Roast::Tools::SearchFile",
            ],
            "steps" => ["step1"],
          }
          temp_file.write(config_hash.to_yaml)
          temp_file.close

          begin
            config = Configuration.new(temp_file.path)

            # Check that all tools are parsed correctly
            assert_equal(
              [
                "Roast::Tools::Grep",
                "Roast::Tools::Cmd",
                "Roast::Tools::ReadFile",
                "Roast::Tools::SearchFile",
              ],
              config.tools,
            )

            # Check that tool configurations are stored correctly
            assert_equal({}, config.tool_config("Roast::Tools::Grep"))
            assert_equal({ "allowed_commands" => ["sed", "gh", "ruby"] }, config.tool_config("Roast::Tools::Cmd"))
            assert_equal({}, config.tool_config("Roast::Tools::ReadFile"))
            assert_equal({}, config.tool_config("Roast::Tools::SearchFile"))

            # Check that non-existent tool returns empty hash
            assert_equal({}, config.tool_config("NonExistent::Tool"))
          ensure
            temp_file.unlink
          end
        end

        def test_handles_tools_with_only_string_format_backward_compatibility
          temp_file = Tempfile.new(["string_tools_only", ".yml"], FIXTURES)
          config_hash = {
            "name" => "String Tools Test",
            "tools" => [
              "Roast::Tools::Grep",
              "Roast::Tools::ReadFile",
            ],
            "steps" => ["step1"],
          }
          temp_file.write(config_hash.to_yaml)
          temp_file.close

          begin
            config = Configuration.new(temp_file.path)

            # Check that tools are parsed correctly
            assert_equal(2, config.tools.length)
            assert_includes(config.tools, "Roast::Tools::Grep")
            assert_includes(config.tools, "Roast::Tools::ReadFile")

            # Check that no tool configurations are stored (all should be empty hashes)
            assert_equal({}, config.tool_config("Roast::Tools::Grep"))
            assert_equal({}, config.tool_config("Roast::Tools::ReadFile"))
          ensure
            temp_file.unlink
          end
        end

        def test_handles_tools_with_only_hash_format
          temp_file = Tempfile.new(["hash_tools_only", ".yml"], FIXTURES)
          config_hash = {
            "name" => "Hash Tools Test",
            "tools" => [
              { "Roast::Tools::Cmd" => { "allowed_commands" => ["git", "npm"] } },
              { "Roast::Tools::Grep" => nil }, # Shows hash format works even without config
            ],
            "steps" => ["step1"],
          }
          temp_file.write(config_hash.to_yaml)
          temp_file.close

          begin
            config = Configuration.new(temp_file.path)

            # Check that tools are parsed correctly
            assert_equal(2, config.tools.length)
            assert_includes(config.tools, "Roast::Tools::Cmd")
            assert_includes(config.tools, "Roast::Tools::Grep")

            # Check that tool configurations are stored correctly
            assert_equal({ "allowed_commands" => ["git", "npm"] }, config.tool_config("Roast::Tools::Cmd"))
            assert_equal({}, config.tool_config("Roast::Tools::Grep")) # Empty since Grep doesn't support config
          ensure
            temp_file.unlink
          end
        end

        def test_handles_empty_tools_configuration
          temp_file = Tempfile.new(["empty_tools", ".yml"], FIXTURES)
          config_hash = {
            "name" => "Empty Tools Test",
            "steps" => ["step1"],
          }
          temp_file.write(config_hash.to_yaml)
          temp_file.close

          begin
            config = Configuration.new(temp_file.path)

            # Check that empty tools are handled correctly
            assert_empty(config.tools)
            assert_empty(config.tool_configs)
            assert_equal({}, config.tool_config("Any::Tool"))
          ensure
            temp_file.unlink
          end
        end
      end

      class WriteFileConfigTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures", __dir__)

        def setup
          @options = {}
          @workflow_path = File.join(FIXTURES, "workflow_with_write_file_config.yml")
        end

        def test_write_file_function_config
          configuration = Roast::Workflow::Configuration.new(@workflow_path, @options)
          write_file_config = configuration.function_config("write_file")

          assert_equal(true, write_file_config["cached"])
          assert_equal("src/", write_file_config["params"]["restrict"])
        end
      end

      class ApiProviderEnvironmentTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../test/fixtures/files", __dir__)

        def fixture_file(filename)
          File.join(FIXTURES, filename)
        end

        def setup
          @options = {}
          @original_openai_key = ENV["OPENAI_API_KEY"]
          @original_openrouter_key = ENV["OPENROUTER_API_KEY"]
          ENV["OPENAI_API_KEY"] = "env-openai-key"
          ENV["OPENROUTER_API_KEY"] = "env-openrouter-key"
        end

        def teardown
          ENV["OPENAI_API_KEY"] = @original_openai_key
          ENV["OPENROUTER_API_KEY"] = @original_openai_key
        end

        def test_uses_openai_env_var_when_provider_is_openai
          configuration = Roast::Workflow::Configuration.new(fixture_file("openai_no_api_token_workflow.yml"), @options)
          assert_equal("openai", configuration.api_provider.to_s)
          assert_equal("env-openai-key", configuration.api_token)
        end

        def test_uses_openrouter_env_var_when_provider_is_openai
          configuration = Roast::Workflow::Configuration.new(fixture_file("openrouter_no_api_token_workflow.yml"), @options)
          assert_equal("openrouter", configuration.api_provider.to_s)
          assert_equal("env-openrouter-key", configuration.api_token)
        end

        def test_uses_specified_api_token_when_provided
          configuration = Roast::Workflow::Configuration.new(fixture_file("openrouter_workflow.yml"), @options)
          assert_equal("openrouter", configuration.api_provider.to_s)
          assert_equal("test_openrouter_token", configuration.api_token)
        end
      end
    end
  end
end
