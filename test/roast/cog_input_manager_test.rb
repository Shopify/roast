# frozen_string_literal: true

require "test_helper"

module Roast
  class CogInputManagerTest < ActiveSupport::TestCase
    def setup
      @temp_dir = Dir.mktmpdir
      @workflow_dir = File.join(@temp_dir, "workflow")
      @prompts_dir = File.join(@workflow_dir, "prompts")
      FileUtils.mkdir_p(@prompts_dir)

      @template_path = File.join(@prompts_dir, "test_template.md.erb")
      File.write(@template_path, <<~ERB)
        Hello <%= name %>!
        This is a test template.
      ERB

      @cog_registry = Cog::Registry.new
      @cogs = Cog::Store.new
    end

    def teardown
      FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    end

    test "template method resolves shorthand paths relative to workflow directory" do
      manager = create_manager(workflow_dir: Pathname.new(@workflow_dir))

      Dir.chdir(@temp_dir) do
        result = manager.context.template("test_template", { name: "Workflow Dir" })
        assert_includes result, "Hello Workflow Dir!"
        assert_includes result, "This is a test template."
      end
    end

    test "template method falls back to current working directory" do
      other_workflow_dir = File.join(@temp_dir, "other_workflow")
      FileUtils.mkdir_p(other_workflow_dir)

      manager = create_manager(workflow_dir: Pathname.new(other_workflow_dir))

      Dir.chdir(@workflow_dir) do
        result = manager.context.template("test_template", { name: "Fallback" })
        assert_includes result, "Hello Fallback!"
        assert_includes result, "This is a test template."
      end
    end

    test "template method fails when template cannot be found in any search locations" do
      manager = create_manager(workflow_dir: Pathname.new(@workflow_dir))

      Dir.chdir(@workflow_dir) do
        error = assert_raises(CogInputContext::ContextNotFoundError) do
          manager.context.template("nonexistent_template_that_doesnt_exist", { name: "World" })
        end
        assert_includes error.message, "The file 'nonexistent_template_that_doesnt_exist' could not be found"
      end
    end

    test "template method works with absolute path" do
      manager = create_manager

      absolute_path = Pathname.new(@template_path).realpath
      result = manager.context.template(absolute_path, { name: "Full Path" })
      assert_includes result, "Hello Full Path!"
      assert_includes result, "This is a test template."
    end

    private

    # Factory method to create a CogInputManager with realistic instances
    #
    # @param workflow_dir [Pathname] The workflow directory path (defaults to @workflow_dir)
    # @return [CogInputManager] Configured manager instance
    def create_manager(workflow_dir: Pathname.new(@workflow_dir))
      params = WorkflowParams.new([], [], {})
      workflow_context = WorkflowContext.new(
        params: params,
        tmpdir: @temp_dir,
        workflow_dir: workflow_dir,
      )

      CogInputManager.new(@cog_registry, @cogs, workflow_context)
    end
  end
end
