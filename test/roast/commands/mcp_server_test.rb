# frozen_string_literal: true

require "test_helper"
require "roast/commands/mcp_server"
require "tempfile"
require "tmpdir"

module Roast
  module Commands
    class McpServerTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @server = nil
      end

      def teardown
        FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
      end

      test "discovers workflows in specified directories" do
        # Create a test workflow
        workflow_path = File.join(@temp_dir, "test_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Test Workflow
          description: A test workflow
          steps:
            - step1: Do something
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])

        assert_equal 1, server.tools.length
        assert_equal "roast_test_workflow", server.tools.first["name"]
        assert_equal "A test workflow", server.tools.first["description"]
      end

      test "handles initialize request" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => {
            "protocolVersion" => "2024-11-05",
          },
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 1, response["id"]
        assert_equal "2024-11-05", response.dig("result", "protocolVersion")
        assert_equal "roast-mcp-server", response.dig("result", "serverInfo", "name")
        assert server.initialized
      end

      test "rejects unsupported protocol version" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => {
            "protocolVersion" => "9999-99-99",
          },
        }

        response = server.send(:process_message, request)

        assert_equal(-32602, response.dig("error", "code"))
        assert_match(/Unsupported protocol version/, response.dig("error", "message"))
        refute server.initialized
      end

      test "accepts alternate protocol version 0.1.0" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => {
            "protocolVersion" => "0.1.0",
          },
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 1, response["id"]
        assert_equal "0.1.0", response.dig("result", "protocolVersion")
        assert server.initialized
      end

      test "accepts protocol version 2025-03-26 with adapted capabilities" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => {
            "protocolVersion" => "2025-03-26",
          },
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 1, response["id"]
        assert_equal "2025-03-26", response.dig("result", "protocolVersion")
        # Check that completions capability is adapted to object format
        assert_equal({ "enabled" => false }, response.dig("result", "capabilities", "completions"))
        assert server.initialized
      end

      test "handles tools/list request" do
        workflow_path = File.join(@temp_dir, "test_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Test Workflow
          steps:
            - step1: Do something
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/list",
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 2, response["id"]
        assert_equal 1, response.dig("result", "tools").length
        assert_equal "roast_test_workflow", response.dig("result", "tools", 0, "name")
      end

      test "handles ping request" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "ping",
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 3, response["id"]
        assert_equal({}, response["result"])
      end

      test "handles shutdown request" do
        server = McpServer.new
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 4,
          "method" => "shutdown",
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 4, response["id"]
        assert_nil response["result"]
        refute server.initialized
      end

      test "rejects requests when not initialized" do
        server = McpServer.new
        request = {
          "jsonrpc" => "2.0",
          "id" => 5,
          "method" => "tools/list",
        }

        response = server.send(:process_message, request)

        assert_equal(-32002, response.dig("error", "code"))
        assert_match(/Server not initialized/, response.dig("error", "message"))
      end

      test "builds input schema from workflow config" do
        config = {
          "name" => "Test",
          "target" => "*.rb",
          "steps" => [
            "analyze {{file_type}} files",
            "process with {{model}}",
          ],
        }

        server = McpServer.new
        schema = server.send(:build_input_schema, config)

        assert_equal "object", schema["type"]
        assert schema["properties"].key?("target")
        assert schema["properties"].key?("file_type")
        assert schema["properties"].key?("model")
      end

      test "extracts variables from workflow config" do
        config = {
          "steps" => [
            "analyze {{language}} code",
            "use {{model}} for processing",
            "save to {{output_dir}}",
          ],
        }

        server = McpServer.new
        variables = server.send(:extract_variables, config)

        assert_equal 3, variables.length
        assert_includes variables, "language"
        assert_includes variables, "model"
        assert_includes variables, "output_dir"
      end

      test "extracts ERB variables from workflow config" do
        config = {
          "steps" => [
            "analyze <%= workflow.file %>",
            "process with <%= workflow.model %>",
            "check ENV['ROAST_API_KEY']",
          ],
        }

        server = McpServer.new
        variables = server.send(:extract_variables, config)

        assert_includes variables, "file"
        assert_includes variables, "model"
        assert_includes variables, "api_key"
      end

      test "workflow with each field gets file parameter" do
        workflow_path = File.join(@temp_dir, "each_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Each Workflow
          each: 'git ls-files | grep test'
          steps:
            - analyze: Process <%= workflow.file %>
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        tool = server.tools.find { |t| t["name"] == "roast_each_workflow" }

        assert tool["inputSchema"]["properties"].key?("file")
        assert_equal "File to process with this workflow",
          tool["inputSchema"]["properties"]["file"]["description"]
      end

      test "workflow without parameters gets default file parameter" do
        workflow_path = File.join(@temp_dir, "simple_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Simple Workflow
          steps:
            - analyze: Just analyze something
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        tool = server.tools.find { |t| t["name"] == "roast_simple_workflow" }

        assert tool["inputSchema"]["properties"].key?("file")
        assert_equal "File or input for the workflow",
          tool["inputSchema"]["properties"]["file"]["description"]
      end

      test "handles unknown method" do
        server = McpServer.new
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 6,
          "method" => "unknown/method",
        }

        response = server.send(:process_message, request)

        assert_equal(-32601, response.dig("error", "code"))
        assert_match(/Method not found/, response.dig("error", "message"))
      end

      test "handles prompts/list request" do
        server = McpServer.new
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 7,
          "method" => "prompts/list",
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 7, response["id"]
        assert_equal [], response.dig("result", "prompts")
      end

      test "handles resources/list request" do
        server = McpServer.new
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 8,
          "method" => "resources/list",
        }

        response = server.send(:process_message, request)

        assert_equal "2.0", response["jsonrpc"]
        assert_equal 8, response["id"]
        assert_equal [], response.dig("result", "resources")
      end

      test "workflow with no name uses filename" do
        workflow_path = File.join(@temp_dir, "my_custom_workflow.yml")
        File.write(workflow_path, <<~YAML)
          steps:
            - analyze: Analyze the code
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])

        assert_equal 1, server.tools.length
        assert_equal "roast_my_custom_workflow", server.tools.first["name"]
      end

      test "skips invalid workflow files" do
        # Create an invalid workflow
        invalid_path = File.join(@temp_dir, "invalid.yml")
        File.write(invalid_path, "not a valid workflow")

        # Create a valid workflow
        valid_path = File.join(@temp_dir, "valid.yml")
        File.write(valid_path, <<~YAML)
          name: Valid Workflow
          steps:
            - step1: Do something
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])

        assert_equal 1, server.tools.length
        assert_equal "roast_valid_workflow", server.tools.first["name"]
      end
    end
  end
end
