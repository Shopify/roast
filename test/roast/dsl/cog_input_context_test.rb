# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class CogInputManagerTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @workflow_dir = File.join(@temp_dir, "dsl")
        @prompts_dir = File.join(@workflow_dir, "prompts")
        FileUtils.mkdir_p(@prompts_dir)

        # Create a test template file in the dsl/prompts directory
        @template_path = File.join(@prompts_dir, "test_template.md.erb")
        File.write(@template_path, <<~ERB)
          Hello <%= name %>!
          This is a test template.
        ERB

        # Mock objects for CogInputManager
        @cog_registry = mock("cog_registry")
        @cog_registry.stubs(:cogs).returns({})
        @cogs = Cog::Store.new

        @params = mock("params")
        @params.stubs(:targets).returns([])
        @params.stubs(:args).returns([])
        @params.stubs(:kwargs).returns({})

        @workflow_context = mock("workflow_context")
        @workflow_context.stubs(:params).returns(@params)
        @workflow_context.stubs(:tmpdir).returns(@temp_dir)
      end

      def teardown
        FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      test "template method resolves shorthand paths relative to workflow directory when provided" do
        workflow_dir = Pathname.new(@workflow_dir)
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context, workflow_dir)

        # Change to different directory to test the fix
        Dir.chdir(@temp_dir) do
          result = manager.context.template("test_template", { name: "Workflow Dir" })
          assert_includes result, "Hello Workflow Dir!"
          assert_includes result, "This is a test template."
        end
      end

      test "template method falls back to current working directory when workflow_dir not provided" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context, nil)

        Dir.chdir(@workflow_dir) do
          result = manager.context.template("test_template", { name: "Fallback" })
          assert_includes result, "Hello Fallback!"
          assert_includes result, "This is a test template."
        end
      end

      test "template method fails with shorthand syntax when not in correct directory and no workflow_dir" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context, nil)

        # This test demonstrates the bug when workflow_dir is not provided
        Dir.chdir(@temp_dir) do # Change to temp_dir, not the workflow dir
          error = assert_raises(CogInputContext::ContextNotFoundError) do
            manager.context.template("test_template", { name: "World" })
          end
          assert_includes error.message, "The prompt prompts/test_template.md.erb could not be found"
        end
      end

      test "template method works with full path" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context, nil)

        result = manager.context.template(@template_path, { name: "Full Path" })
        assert_includes result, "Hello Full Path!"
        assert_includes result, "This is a test template."
      end

      test "template method fails when template file does not exist" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context, nil)

        error = assert_raises(CogInputContext::ContextNotFoundError) do
          manager.context.template("nonexistent_template")
        end
        assert_includes error.message, "could not be found"
      end
    end
  end
end
