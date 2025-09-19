# typed: true
# frozen_string_literal: true

require "test_helper"
require "roast/tui/tools"

module Roast
  module TUI
    class ToolsTest < ActiveSupport::TestCase
      test "all tool files load without errors" do
        assert_nothing_raised { Tools }
        assert_nothing_raised { Tools::Base }
        assert_nothing_raised { Tools::FileOperations }
        assert_nothing_raised { Tools::SearchOperations }
        assert_nothing_raised { Tools::SystemOperations }
        assert_nothing_raised { Tools::TaskManagement }
      end

      test "get_tool returns correct tool instances" do
        read_tool = Tools.get_tool("read")
        assert_instance_of Tools::FileOperations::Read, read_tool
        assert_equal "read", read_tool.name

        bash_tool = Tools.get_tool("bash")
        assert_instance_of Tools::SystemOperations::Bash, bash_tool
        assert_equal "bash", bash_tool.name

        todo_tool = Tools.get_tool("todo")
        assert_instance_of Tools::TaskManagement::Todo, todo_tool
        assert_equal "todo", todo_tool.name
      end

      test "available_tools returns all tool names" do
        tools = Tools.available_tools
        assert_includes tools, "read"
        assert_includes tools, "write"
        assert_includes tools, "edit"
        assert_includes tools, "bash"
        assert_includes tools, "grep"
        assert_includes tools, "todo"
        assert_equal 14, tools.length
      end

      test "tool_categories organizes tools properly" do
        categories = Tools.tool_categories
        assert_equal 4, categories.length
        assert_includes categories["File Operations"], "read"
        assert_includes categories["Search Operations"], "grep"
        assert_includes categories["System Operations"], "bash"
        assert_includes categories["Task Management"], "todo"
      end

      test "openai_tools_spec generates valid schemas" do
        specs = Tools.openai_tools_spec
        assert specs.is_a?(Array)
        assert specs.length > 0

        # Check a specific tool schema
        read_spec = specs.find { |s| s[:function][:name] == "read" }
        assert read_spec
        assert_equal "function", read_spec[:type]
        assert read_spec[:function][:description]
        assert read_spec[:function][:parameters]
      end

      test "base tool validates required arguments" do
        tool = Tools::FileOperations::Read.new
        
        # Missing required argument
        error = assert_raises(Tools::Base::ValidationError) do
          tool.execute({})
        end
        assert_match(/Missing required parameters/, error.message)

        # Valid arguments
        assert_nothing_raised do
          tool.execute({ "file_path" => "/tmp/test.txt" })
        rescue Tools::Base::ValidationError => e
          # File not found is expected, but argument validation should pass
          assert_match(/File not found/, e.message)
        end
      end

      test "base tool validates argument types" do
        tool = Tools::FileOperations::Read.new
        
        # Invalid type for limit (should be integer)
        error = assert_raises(Tools::Base::ValidationError) do
          tool.execute({ "file_path" => "/tmp/test.txt", "limit" => "not_a_number" })
        end
        assert_match(/must be of type/, error.message)
      end

      test "base tool validates enum values" do
        tool = Tools::FileOperations::Ls.new
        
        # Invalid enum value
        error = assert_raises(Tools::Base::ValidationError) do
          tool.execute({ "sort" => "invalid_sort" })
        end
        assert_match(/must be one of/, error.message)
      end

      test "todo tool validates task rules" do
        todo_tool = Tools::TaskManagement::Todo.new
        
        # Multiple in_progress tasks should fail
        todos = [
          { "content" => "Task 1", "activeForm" => "Working on task 1", "status" => "in_progress" },
          { "content" => "Task 2", "activeForm" => "Working on task 2", "status" => "in_progress" }
        ]
        
        error = assert_raises(Tools::Base::ValidationError) do
          todo_tool.execute({ "todos" => todos })
        end
        assert_match(/Only one task can be in_progress/, error.message)
      end

      test "tools can be registered with a registry" do
        registry = ToolRegistry.new
        Tools.register_all(registry)
        
        # Check that tools are registered
        assert_includes registry.tool_names, "read"
        assert_includes registry.tool_names, "bash"
        assert_includes registry.tool_names, "todo"
      end

      test "parallel_safe flag is set correctly" do
        # Read operations should be parallel safe
        read_tool = Tools.get_tool("read")
        assert read_tool.parallel_safe?
        
        # Write operations should not be parallel safe
        write_tool = Tools.get_tool("write")
        refute write_tool.parallel_safe?
        
        # Bash should not be parallel safe
        bash_tool = Tools.get_tool("bash")
        refute bash_tool.parallel_safe?
      end

      test "tool permission modes work correctly" do
        tool = Tools::FileOperations::Write.new
        assert_equal :ask, tool.permission_mode
        
        # Configure permissions
        Tools.configure_permissions({ "write" => :deny })
        tool = Tools.get_tool("write")
        assert_equal :deny, tool.permission_mode
      end
    end
  end
end