# frozen_string_literal: true

require "test_helper"
require "roast/workflow/step_loader"

module Roast
  module Workflow
    class StepLoaderTest < Minitest::Test
      include FixtureHelpers

      def setup
        @workflow = BaseWorkflow.new(nil, name: "test_workflow")
        @workflow.output = {}
        @context_path = File.expand_path("../../fixtures/steps", __dir__)
        @config_hash = {}
        @step_loader = StepLoader.new(@workflow, @config_hash, @context_path)
      end

      def test_loads_prompt_step_when_name_contains_spaces
        step = @step_loader.load("analyze the code")

        assert_instance_of(PromptStep, step)
        assert_equal("analyze the code", step.name)
        refute(step.auto_loop)
      end

      def test_loads_ruby_step_from_context_path
        # Create a temporary step file
        Dir.mktmpdir do |dir|
          step_file = File.join(dir, "test_step.rb")
          File.write(step_file, <<~RUBY)
            require "roast/workflow/base_step"

            class TestStep < Roast::Workflow::BaseStep
              def call
                "Test step executed"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, dir)
          step = loader.load("test_step")

          assert_instance_of(TestStep, step)
          assert_equal("test_step", step.name)
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

          step_file = File.join(shared_dir, "test_step.rb")
          File.write(step_file, <<~RUBY)
            require "roast/workflow/base_step"

            class TestStep < Roast::Workflow::BaseStep
              def call
                "Test step from shared"
              end
            end
          RUBY

          loader = StepLoader.new(@workflow, @config_hash, context_dir)
          step = loader.load("test_step")

          assert_instance_of(TestStep, step)
          assert_equal("test_step", step.name)
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
        @config_hash["model"] = "workflow-default"

        step = @step_loader.load("test")

        assert_equal("workflow-default", step.model)
      end

      def test_uses_default_model_when_no_config
        step = @step_loader.load("test")

        assert_equal(StepLoader::DEFAULT_MODEL, step.model)
      end

      def test_applies_step_configuration
        @config_hash["test"] = {
          "print_response" => true,
          "loop" => true,
          "json" => true,
          "params" => { "key" => "value" },
        }

        step = @step_loader.load("test")

        assert_equal(true, step.print_response)
        assert_equal(true, step.auto_loop)
        assert_equal(true, step.json)
        assert_equal({ "key" => "value" }, step.params)
      end

      def test_sets_resource_when_supported
        require "roast/resources/file_resource"
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
    end
  end
end
