# typed: true
# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/file_operations"
require_relative "tools/search_operations"
require_relative "tools/system_operations"
require_relative "tools/task_management"

module Roast
  module TUI
    module Tools
      class << self
        # Register all OpenCode-compatible tools with the given registry
        def register_all(registry)
          FileOperations.register_all(registry)
          SearchOperations.register_all(registry)
          SystemOperations.register_all(registry)
          TaskManagement.register_all(registry)
        end

        # Create a new registry with all tools registered
        def create_registry
          registry = ToolRegistry.new
          register_all(registry)
          registry
        end

        # Get a specific tool instance by name
        def get_tool(name)
          case name
          when "read"
            FileOperations::Read.new
          when "write"
            FileOperations::Write.new
          when "edit"
            FileOperations::Edit.new
          when "multiedit"
            FileOperations::MultiEdit.new
          when "glob"
            FileOperations::Glob.new
          when "ls"
            FileOperations::Ls.new
          when "grep"
            SearchOperations::Grep.new
          when "find"
            SearchOperations::Find.new
          when "bash"
            SystemOperations::Bash.new
          when "bash_output"
            SystemOperations::BashOutput.new
          when "kill_bash"
            SystemOperations::KillBash.new
          when "webfetch"
            SystemOperations::WebFetch.new
          when "todo"
            TaskManagement::Todo.new
          else
            nil
          end
        end

        # Get all available tool names
        def available_tools
          %w[
            read write edit multiedit glob ls
            grep find
            bash bash_output kill_bash webfetch
            todo
          ]
        end

        # Get tool descriptions for help text
        def tool_descriptions
          {
            # File Operations
            "read" => "Read file contents with line numbers, supports images and PDFs",
            "write" => "Write content to a file with overwrite protection",
            "edit" => "Edit files with various strategies (simple, line-based, block, regex)",
            "multiedit" => "Perform multiple edits to a single file in one operation",
            "glob" => "Find files matching glob patterns",
            "ls" => "List directory contents with details",
            
            # Search Operations
            "grep" => "Search file contents using ripgrep with regex support",
            "find" => "Find files by name or path patterns",
            
            # System Operations
            "bash" => "Execute shell commands with timeout and background support",
            "bash_output" => "Retrieve output from a background bash process",
            "kill_bash" => "Kill a background bash process",
            "webfetch" => "Fetch and process web content",
            
            # Task Management
            "todo" => "Manage a task list for the current session"
          }
        end

        # Get tool categories for organized help
        def tool_categories
          {
            "File Operations" => %w[read write edit multiedit glob ls],
            "Search Operations" => %w[grep find],
            "System Operations" => %w[bash bash_output kill_bash webfetch],
            "Task Management" => %w[todo]
          }
        end

        # Generate OpenAI tools specification for all tools
        def openai_tools_spec
          available_tools.map do |tool_name|
            tool = get_tool(tool_name)
            tool&.to_openai_schema
          end.compact
        end

        # Configure tool permissions
        def configure_permissions(permissions = {})
          # permissions is a hash of tool_name => :ask/:allow/:deny
          permissions.each do |tool_name, mode|
            tool = get_tool(tool_name)
            if tool
              tool.instance_variable_set(:@permission_mode, mode)
            end
          end
        end
      end
    end
  end
end