# frozen_string_literal: true

# Example test file for Roast workflows.
#
# This demonstrates how to use Roast::Testing::WorkflowTest to write tests
# for your own workflows. Copy and adapt this to your project.
#
# Run with:
#   bundle exec ruby -Itest examples/test/example_workflow_test.rb

require_relative "test_helper"

class ExampleWorkflowTest < Roast::Testing::WorkflowTest
  # Point to the directory containing your workflow files.
  # Everything in this directory gets copied into an isolated sandbox for each test.
  self.workflow_dir = File.expand_path("..", __dir__)

  # -----------------------------------------------------------
  # Capturing log output
  # -----------------------------------------------------------
  #
  # Roast logs workflow execution via Roast::Log (which writes to $stderr).
  # To capture and assert on log output, redirect the logger to a StringIO.
  #
  setup do
    @log_output = StringIO.new
    Roast::Log.logger = Logger.new(@log_output)
  end

  teardown do
    Roast::Log.reset!
  end

  # -----------------------------------------------------------
  # Basic test: run a workflow and verify it completes
  # -----------------------------------------------------------
  #
  # `in_sandbox` does the following:
  #   1. Creates a temp directory
  #   2. Copies your workflow_dir contents into it
  #   3. Sets up fake API credentials (for VCR playback)
  #   4. Wraps the block in a VCR cassette (if VCR is loaded)
  #   5. Returns [stdout, stderr] with temp paths sanitized
  #
  test "ruby_cog workflow runs successfully" do
    in_sandbox(:ruby_cog) do
      Roast::Workflow.from_file("examples/ruby_cog.rb", EMPTY_PARAMS)
    end

    # Check log output for completion
    assert_match(/Workflow Complete/, @log_output.string)
  end

  # -----------------------------------------------------------
  # Testing with parameters
  # -----------------------------------------------------------
  #
  # Use Roast::WorkflowParams to pass targets and arguments to your workflow.
  # EMPTY_PARAMS is a convenience constant for workflows that don't need any.
  #
  test "workflow accepts custom parameters" do
    params = Roast::WorkflowParams.new(
      [],           # targets - files or items to process
      [],           # positional args
      {},           # keyword args
    )

    in_sandbox(:params_test) do
      Roast::Workflow.from_file("examples/ruby_cog.rb", params)
    end

    assert_match(/Workflow Complete/, @log_output.string)
    # No ERROR-level entries in the log
    refute_match(/ERROR/, @log_output.string)
  end

  # -----------------------------------------------------------
  # Testing workflows that use shell commands
  # -----------------------------------------------------------
  #
  # Workflows using `cmd` cogs run shell commands. These run normally
  # inside the sandbox. The sandbox is a temp directory, so commands
  # won't affect your real files.
  #
  test "shell workflow runs commands in sandbox" do
    in_sandbox(:shell_test) do
      Roast::Workflow.from_file("examples/shell_sanitization.rb", EMPTY_PARAMS)
    end

    assert_match(/Workflow Complete/, @log_output.string)
  end

  # -----------------------------------------------------------
  # Testing that errors are raised properly
  # -----------------------------------------------------------
  #
  # Use standard Minitest assertions to verify error handling.
  #
  test "nonexistent workflow raises error" do
    assert_raises(Errno::ENOENT) do
      in_sandbox(:error_test) do
        Roast::Workflow.from_file("examples/does_not_exist.rb", EMPTY_PARAMS)
      end
    end
  end
end
