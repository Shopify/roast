# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepLoaderTest < ActiveSupport::TestCase
      include FixtureHelpers

      def setup
        @original_openai_key = ENV.delete("OPENAI_API_KEY")
        @workflow = BaseWorkflow.new(nil, name: "test_workflow")
        @workflow.output = {}
        @context_path = File.expand_path("../../fixtures/steps", __dir__)
        @config_hash = {}
        @step_loader = StepLoader.new(@workflow, @config_hash, @context_path)
      end

      def teardown
        ENV["OPENAI_API_KEY"] = @original_openai_key
      end

      def test_loads_prompt_step_when_name_contains_spaces
        step = @step_loader.load("analyze the code")

        assert_instance_of(PromptStep, step)
        assert_equal("analyze the code", step.name)
      end

      def test_loads_ruby_step_from_context_path
        # Create a temporary step file
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "context_test_step.rb")
          File.write(step_file, <<~RUBY)
            class ContextTestStep < Roast::Workflow::BaseStep
              def call
                "Test step executed"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("context_test_step")

          assert_instance_of(ContextTestStep, step)
          assert_equal("context_test_step", step.name)
          assert_equal(dir, step.context_path)
        end
      end

      def test_loads_ruby_step_from_shared_directory
        # Create a temporary directory structure
        Dir.mktmpdir do |base_dir|
          context_dir = File.join(base_dir, "steps", "specific")
          shared_dir = File.join(base_dir, "steps", "shared")
          FileUtils.mkdir_p(context_dir)
          FileUtils.mkdir_p(shared_dir)

          step_file = File.join(shared_dir, "shared_test_step.rb")
          File.write(step_file, <<~RUBY)
            class SharedTestStep < Roast::Workflow::BaseStep
              def call
                "Test step from shared"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, context_dir)
          step = loader.load("shared_test_step")

          assert_instance_of(SharedTestStep, step)
          assert_equal("shared_test_step", step.name)
          assert_equal(shared_dir, step.context_path)
        end
      end

      def test_loads_directory_based_step
        step = @step_loader.load("test")

        assert_instance_of(BaseStep, step)
        assert_equal("test", step.name)
        assert_equal(File.join(@context_path, "test"), step.context_path)
      end

      def test_raises_error_for_missing_step
        error = assert_raises(StepLoader::StepNotFoundError) do
          @step_loader.load("nonexistent_step")
        end

        assert_equal("nonexistent_step", error.step_name)
        assert_match(/Step directory or file not found/, error.message)
      end

      def test_configures_step_with_model
        @config_hash["test"] = { "model" => "custom-model" }

        step = @step_loader.load("test")

        assert_equal("custom-model", step.model)
      end

      def test_uses_workflow_default_model
        # With StepLoader no longer setting defaults from config_hash,
        # the workflow-level default should be respected.
        @workflow.model = "workflow-default"

        step = @step_loader.load("test")

        assert_equal("workflow-default", step.model)
      end

      def test_uses_default_model_when_no_config
        step = @step_loader.load("test")

        assert_equal(StepLoader::DEFAULT_MODEL, step.model)
      end

      def test_step_model_override_workflow_model
        @workflow.model = "workflow-default"
        @config_hash["test"] = { "model" => "custom-model" }
        step = @step_loader.load("test")

        assert_equal("custom-model", step.model)
      end

      def test_applies_step_configuration
        @config_hash["test"] = {
          "print_response" => true,
          "json" => true,
          "params" => { "key" => "value" },
        }

        step = @step_loader.load("test")

        assert_equal(true, step.print_response)
        assert_equal(true, step.json)
        assert_equal({ "key" => "value" }, step.params)
      end

      def test_applies_available_tools_configuration
        @config_hash["test"] = {
          "available_tools" => ["grep", "search_file"],
        }

        step = @step_loader.load("test")

        assert_equal(["grep", "search_file"], step.available_tools)
      end

      def test_does_not_set_available_tools_when_not_configured
        @config_hash["test"] = {
          "json" => true,
          "print_response" => true,
        }

        step = @step_loader.load("test")

        assert_nil(step.available_tools)
      end

      def test_handles_empty_available_tools_array
        @config_hash["test"] = {
          "available_tools" => [],
        }

        step = @step_loader.load("test")

        assert_equal([], step.available_tools)
      end

      def test_sets_resource_when_supported
        @workflow.resource = Roast::Resources::FileResource.new("test.txt")

        step = @step_loader.load("test")

        assert_equal(@workflow.resource, step.resource)
      end

      def test_handles_syntax_error_in_step_file
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "broken_step.rb")
          File.write(step_file, "class BrokenStep < ; end")

          loader = StepLoader.new(@workflow, @config_hash, dir)

          error = assert_raises(StepLoader::StepExecutionError) do
            loader.load("broken_step")
          end

          assert_match(/Syntax error in step file/, error.message)
          assert_equal("broken_step", error.step_name)
        end
      end

      def test_handles_load_error_in_step_file
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "missing_dep_step.rb")
          File.write(step_file, <<~RUBY)
            require "non_existent_gem"

            class MissingDepStep < Roast::Workflow::BaseStep
              def call; end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)

          error = assert_raises(StepLoader::StepNotFoundError) do
            loader.load("missing_dep_step")
          end

          assert_match(/Failed to load step file/, error.message)
          assert_equal("missing_dep_step", error.step_name)
        end
      end

      def test_loads_shell_script_from_context_path
        Dir.mktmpdir do |dir|
          script_file = File.join(dir, "test_script.sh")
          File.write(script_file, "#!/bin/bash\necho 'Hello from shell script'")
          File.chmod(0o755, script_file)

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("test_script")

          assert_instance_of(ShellScriptStep, step)
          assert_equal("test_script", step.name.value)
          assert_equal(script_file, step.script_path)
        end
      end

      def test_loads_shell_script_from_shared_directory
        Dir.mktmpdir do |base_dir|
          context_dir = File.join(base_dir, "steps", "specific")
          shared_dir = File.join(base_dir, "steps", "shared")
          FileUtils.mkdir_p(context_dir)
          FileUtils.mkdir_p(shared_dir)

          script_file = File.join(shared_dir, "shared_script.sh")
          File.write(script_file, "#!/bin/bash\necho 'Hello from shared script'")
          File.chmod(0o755, script_file)

          loader = StepLoader.new(@workflow, @config_hash, context_dir)
          step = loader.load("shared_script")

          assert_instance_of(ShellScriptStep, step)
          assert_equal("shared_script", step.name.value)
          assert_equal(script_file, step.script_path)
        end
      end

      def test_prefers_ruby_over_shell_script_when_both_exist
        Dir.mktmpdir do |dir|
          # Create both Ruby and shell script files
          ruby_file = File.join(dir, "dual_step.rb")
          File.write(ruby_file, <<~RUBY)
            class DualStep < Roast::Workflow::BaseStep
              def call
                "Ruby step executed"
              end
            end
          RUBY

          shell_file = File.join(dir, "dual_step.sh")
          File.write(shell_file, "#!/bin/bash\necho 'Shell script executed'")
          File.chmod(0o755, shell_file)

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("dual_step")

          # Should prefer Ruby step
          assert_instance_of(DualStep, step)
          assert_equal("dual_step", step.name)
        end
      end

      def test_configures_shell_script_step_with_options
        Dir.mktmpdir do |dir|
          script_file = File.join(dir, "configured_script.sh")
          File.write(script_file, "#!/bin/bash\necho '{\"result\": \"success\"}'")
          File.chmod(0o755, script_file)

          @config_hash["configured_script"] = {
            "json" => true,
            "exit_on_error" => false,
            "env" => { "CUSTOM_VAR" => "custom_value" },
          }

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("configured_script")

          assert_instance_of(ShellScriptStep, step)
          assert_equal(true, step.json)
          assert_equal(false, step.exit_on_error)
          assert_equal({ "CUSTOM_VAR" => "custom_value" }, step.env)
        end
      end

      def test_loads_ruby_step_with_plural_name
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "generate_tests.rb")
          File.write(step_file, <<~RUBY)
            class GenerateTests < Roast::Workflow::BaseStep
              def call
                "Tests generated"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("generate_tests")

          assert_instance_of(GenerateTests, step)
          assert_equal("generate_tests", step.name)
          assert_equal(dir, step.context_path)
        end
      end

      def test_loads_ruby_step_with_singular_class_from_plural_step_name
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "analyze_tests.rb")
          File.write(step_file, <<~RUBY)
            class AnalyzeTest < Roast::Workflow::BaseStep
              def call
                "Tests analyzed"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("analyze_tests")

          assert_instance_of(AnalyzeTest, step)
          assert_equal("analyze_tests", step.name)
          assert_equal(dir, step.context_path)
        end
      end

      def test_loads_ruby_step_with_singular_class_from_irregular_plural_step_name
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "do_things.rb")
          File.write(step_file, <<~RUBY)
            class DoThing < Roast::Workflow::BaseStep
              def call
                "Thing done"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("do_things")

          assert_instance_of(DoThing, step)
          assert_equal("do_things", step.name)
          assert_equal(dir, step.context_path)
        end
      end
    end
  end
end
