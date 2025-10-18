# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ShellScriptStepTest < ActiveSupport::TestCase
      def setup
        @workflow = MockWorkflow.new
        @workflow.output = {}
        @workflow.resource = "test_resource"
      end

      test "executes shell script successfully" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Hello from shell script'")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )

          result = step.call
          assert_equal "Hello from shell script", result
        end
      end

      test "handles non-zero exit code with exit_on_error true" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Error!' >&2\nexit 1")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.exit_on_error = true

          assert_raises(::CLI::Kit::Abort) do
            step.call
          end
        end
      end

      test "handles non-zero exit code with exit_on_error false" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Error!' >&2\nexit 1")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.exit_on_error = false

          result = step.call
          assert_equal "Error!", result
        end
      end

      test "passes environment variables to shell script" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho \"Resource: $ROAST_WORKFLOW_RESOURCE\"")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )

          result = step.call
          assert_equal "Resource: test_resource", result
        end
      end

      test "passes workflow output as JSON environment variable" do
        Dir.mktmpdir do |dir|
          @workflow.output = { "previous_step" => "result" }

          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho \"$ROAST_WORKFLOW_OUTPUT\"")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )

          result = step.call
          # Without json: true, the output is returned as a string
          assert_equal('{"previous_step":"result"}', result)
        end
      end

      test "parses JSON output from shell script when json: true" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho '{\"key\": \"value\"}'")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.json = true

          result = step.call
          assert_equal({ "key" => "value" }, result)
        end
      end

      test "returns raw output when json: false" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho '{\"key\": \"value\"}'")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.json = false

          result = step.call
          assert_equal('{"key": "value"}', result)
        end
      end

      test "raises error when JSON parsing fails with json: true" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'This is not valid JSON'")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.json = true

          error = assert_raises(RuntimeError) do
            step.call
          end
          assert_match(/Failed to parse shell script output as JSON/, error.message)
          assert_match(/Output was: This is not valid JSON/, error.message)
        end
      end

      test "raises error when script not found" do
        step = ShellScriptStep.new(
          @workflow,
          script_path: "/nonexistent/script.sh",
          name: ValueObjects::StepName.new("test_script"),
          context_path: "/",
        )

        assert_raises(::CLI::Kit::Abort) do
          step.call
        end
      end

      test "raises error when script not executable" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Hello'")
          # Don't make it executable

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )

          error = assert_raises(::CLI::Kit::Abort) do
            step.call
          end
          assert_match(/not executable/, error.message)
        end
      end

      test "custom environment variables from config" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho \"Custom: $CUSTOM_VAR\"")
          File.chmod(0o755, script_path)

          step = ShellScriptStep.new(
            @workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.env = { "CUSTOM_VAR" => "custom_value" }

          result = step.call
          assert_equal "Custom: custom_value", result
        end
      end

      test "print_response true appends output to final output" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Output to print'")
          File.chmod(0o755, script_path)

          workflow = MockWorkflow.new
          step = ShellScriptStep.new(
            workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.print_response = true

          result = step.call

          assert_equal "Output to print", result
          assert_equal 1, workflow.appended_output.size
          assert_equal "Output to print", workflow.appended_output.first
        end
      end

      test "print_response false does not append output to final output" do
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, "test_script.sh")
          File.write(script_path, "#!/bin/bash\necho 'Output not to print'")
          File.chmod(0o755, script_path)

          workflow = MockWorkflow.new
          step = ShellScriptStep.new(
            workflow,
            script_path: script_path,
            name: ValueObjects::StepName.new("test_script"),
            context_path: dir,
          )
          step.print_response = false

          result = step.call

          assert_equal "Output not to print", result
          assert_empty workflow.appended_output
        end
      end

      class MockWorkflow
        attr_accessor :output, :resource, :storage_type
        attr_reader :appended_output

        def initialize
          @output = {}
          @storage_type = :memory
          @appended_output = []
        end

        def model
          nil
        end

        def append_to_final_output(text)
          @appended_output << text
        end
      end
    end
  end
end
