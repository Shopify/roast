# frozen_string_literal: true

require "test_helper"
require "roast/commands/mcp_server"
require "tempfile"
require "tmpdir"

module Roast
  module Commands
    class McpServerErrorHandlingTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @server = nil
      end

      def teardown
        FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
      end

      test "handles workflow execution error gracefully" do
        # Create a workflow that will fail
        workflow_path = File.join(@temp_dir, "failing_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Failing Workflow
          description: A workflow that fails during execution
          steps:
            - step1:
                cmd: "exit 1"
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => "roast_failing_workflow",
            "arguments" => {},
          },
        }

        response = server.send(:process_message, request)

        # Should return a proper response with isError: true
        assert_equal "2.0", response["jsonrpc"]
        assert_equal 1, response["id"]
        assert response["result"]
        assert response["result"]["isError"]
        assert_match(/Workflow execution failed/, response.dig("result", "content", 0, "text"))
      end

      test "handles workflow with missing step gracefully" do
        # Create a workflow with invalid step reference
        workflow_path = File.join(@temp_dir, "invalid_step_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Invalid Step Workflow
          description: A workflow with invalid step
          steps:
            - nonexistent_step: Do something
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/call",
          "params" => {
            "name" => "roast_invalid_step_workflow",
            "arguments" => {},
          },
        }

        response = server.send(:process_message, request)

        # Should return a proper response with isError: true
        assert_equal "2.0", response["jsonrpc"]
        assert_equal 2, response["id"]
        assert response["result"]
        assert response["result"]["isError"]
        assert_match(/Workflow execution failed/, response.dig("result", "content", 0, "text"))
      end

      test "handles runtime errors in workflow gracefully" do
        # Create a workflow that will have a runtime error
        workflow_path = File.join(@temp_dir, "runtime_error_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Runtime Error Workflow
          description: A workflow with runtime error
          steps:
            - bad_interpolation: "Process {{ undefined_variable }}"
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "tools/call",
          "params" => {
            "name" => "roast_runtime_error_workflow",
            "arguments" => {},
          },
        }

        response = server.send(:process_message, request)

        # Should return a proper response with isError: true
        assert_equal "2.0", response["jsonrpc"]
        assert_equal 3, response["id"]
        assert response["result"]
        assert response["result"]["isError"]
        assert_match(/Workflow execution failed/, response.dig("result", "content", 0, "text"))
      end

      test "server continues running after workflow error" do
        # Create a failing workflow
        workflow_path = File.join(@temp_dir, "failing_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Failing Workflow
          steps:
            - fail:#{" "}
                cmd: "exit 1"
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        # First request - failing workflow
        request1 = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => "roast_failing_workflow",
            "arguments" => {},
          },
        }

        response1 = server.send(:process_message, request1)
        assert response1["result"]["isError"]

        # Second request - ping to verify server is still responsive
        request2 = {
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "ping",
        }

        response2 = server.send(:process_message, request2)
        assert_equal "2.0", response2["jsonrpc"]
        assert_equal 2, response2["id"]
        assert_equal({}, response2["result"])

        # Third request - tools/list to verify server state is intact
        request3 = {
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "tools/list",
        }

        response3 = server.send(:process_message, request3)
        assert_equal "2.0", response3["jsonrpc"]
        assert_equal 3, response3["id"]
        assert_equal 1, response3.dig("result", "tools").length
      end

      test "handles workflow with exit_on_error false" do
        # Create a workflow with exit_on_error: false
        workflow_path = File.join(@temp_dir, "continue_on_error_workflow.yml")
        File.write(workflow_path, <<~YAML)
          name: Continue On Error Workflow
          description: A workflow that continues on error
          steps:
            - failing_step: $(exit 1)
            - success_step: $(echo 'Still running!')

          failing_step:
            exit_on_error: false
        YAML

        server = McpServer.new(workflow_dirs: [@temp_dir])
        server.send(:instance_variable_set, :@initialized, true)

        request = {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => "roast_continue_on_error_workflow",
            "arguments" => {},
          },
        }

        response = server.send(:process_message, request)

        # Should complete successfully despite first step failing
        assert_equal "2.0", response["jsonrpc"]
        assert_equal 1, response["id"]
        assert response["result"]
        refute response["result"]["isError"], "Expected workflow to succeed with exit_on_error: false"
        assert_match(/Still running!/, response.dig("result", "content", 0, "text"))
      end
    end
  end
end
