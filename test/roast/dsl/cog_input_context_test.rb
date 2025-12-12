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
        @workflow_context.stubs(:workflow_dir).returns(Pathname.new(@workflow_dir))
      end

      def teardown
        FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      test "template method resolves shorthand paths relative to workflow directory" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context)

        # Change to different directory to verify template resolution
        Dir.chdir(@temp_dir) do
          result = manager.context.template("test_template", { name: "Workflow Dir" })
          assert_includes result, "Hello Workflow Dir!"
          assert_includes result, "This is a test template."
        end
      end

      test "template method falls back to current working directory" do
        # Create a separate workflow context that points to a non-existent directory
        # to test the current working directory fallback
        @workflow_context.stubs(:workflow_dir).returns(Pathname.new("/non/existent/path"))
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context)

        Dir.chdir(@workflow_dir) do
          result = manager.context.template("test_template", { name: "Fallback" })
          assert_includes result, "Hello Fallback!"
          assert_includes result, "This is a test template."
        end
      end

      test "template method fails when template cannot be found in any search locations" do
        # Use a non-existent workflow directory and change to a directory without templates
        @workflow_context.stubs(:workflow_dir).returns(Pathname.new("/non/existent/path"))
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context)

        # Change to temp_dir which has no prompts directory
        Dir.chdir(@temp_dir) do
          error = assert_raises(CogInputContext::ContextNotFoundError) do
            manager.context.template("test_template", { name: "World" })
          end
          assert_includes error.message, "The file 'test_template' could not be found"
        end
      end

      test "template method works with full path" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context)

        result = manager.context.template(@template_path, { name: "Full Path" })
        assert_includes result, "Hello Full Path!"
        assert_includes result, "This is a test template."
      end

      test "template method fails when template file does not exist" do
        manager = CogInputManager.new(@cog_registry, @cogs, @workflow_context)

        error = assert_raises(CogInputContext::ContextNotFoundError) do
          manager.context.template("nonexistent_template")
        end
        assert_includes error.message, "could not be found"
      end
    end
  end
end
