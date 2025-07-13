# frozen_string_literal: true

require "test_helper"

module Roast
  module Tools
    class CodingAgentOptionsTest < ActiveSupport::TestCase
      def setup
        @original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude -p --verbose --output-format stream-json"
        CodingAgent.configured_command = nil
      end

      def teardown
        ENV["CLAUDE_CODE_COMMAND"] = @original_env
        CodingAgent.configured_command = nil
        CodingAgent.configured_options = {}
      end

      test "build_command adds --continue flag when continue is true" do
        base_command = "claude -p --verbose --output-format stream-json"
        result = CodingAgent.send(:build_command, base_command, continue: true)
        assert_equal "claude --continue -p --verbose --output-format stream-json", result
      end

      test "build_command returns base command when continue is false" do
        base_command = "claude -p --verbose --output-format stream-json"
        result = CodingAgent.send(:build_command, base_command, continue: false)
        assert_equal base_command, result
      end

      test "build_command handles non-standard commands" do
        base_command = "custom-claude-wrapper --some-flag"
        result = CodingAgent.send(:build_command, base_command, continue: true)
        assert_equal "custom-claude-wrapper --some-flag --continue", result
      end

      test "prepare_prompt returns original prompt when include_context_summary is false" do
        prompt = "Test prompt"
        result = CodingAgent.send(:prepare_prompt, prompt, false)
        assert_equal prompt, result
      end

      test "prepare_prompt adds context summary when include_context_summary is true" do
        # Create a mock workflow context
        workflow = mock
        workflow.stubs(:config).returns({ "description" => "Test workflow" })
        workflow.stubs(:output).returns({ "step1" => "output1", "step2" => "output2" })
        workflow.stubs(:name).returns("test_workflow")

        context = mock
        context.stubs(:workflow).returns(workflow)

        Thread.current[:workflow_context] = context

        # Mock the ContextSummarizer
        mock_summarizer = mock
        mock_summarizer.stubs(:generate_summary).returns("This is a test workflow that has completed step1 and step2.")
        Roast::Tools::ContextSummarizer.stubs(:new).returns(mock_summarizer)

        prompt = "Test prompt"
        result = CodingAgent.send(:prepare_prompt, prompt, true)

        assert_includes result, "<system>"
        assert_includes result, "This is a test workflow that has completed step1 and step2."
        assert_includes result, "</system>"
        assert_includes result, "Test prompt"

        Thread.current[:workflow_context] = nil
      end

      test "generate_context_summary handles missing workflow context" do
        Thread.current[:workflow_context] = nil
        result = CodingAgent.send(:generate_context_summary, "Test prompt")
        assert_nil result
      end

      test "generate_context_summary uses ContextSummarizer" do
        # Create a mock workflow context
        workflow = mock
        context = mock
        context.stubs(:workflow).returns(workflow)

        Thread.current[:workflow_context] = context

        # Mock the ContextSummarizer
        mock_summarizer = mock
        mock_summarizer.expects(:generate_summary).with(context, "Test agent prompt").returns("Generated summary")
        Roast::Tools::ContextSummarizer.stubs(:new).returns(mock_summarizer)

        result = CodingAgent.send(:generate_context_summary, "Test agent prompt")
        assert_equal "Generated summary", result

        Thread.current[:workflow_context] = nil
      end

      test "prepare_prompt returns original prompt when summary is 'No relevant information found in the workflow context.'" do
        # Create a mock workflow context
        workflow = mock
        context = mock
        context.stubs(:workflow).returns(workflow)

        Thread.current[:workflow_context] = context

        # Mock the ContextSummarizer to return "No relevant information found in the workflow context."
        mock_summarizer = mock
        mock_summarizer.stubs(:generate_summary).returns("No relevant information found in the workflow context.")
        Roast::Tools::ContextSummarizer.stubs(:new).returns(mock_summarizer)

        prompt = "Test prompt"
        result = CodingAgent.send(:prepare_prompt, prompt, true)
        assert_equal prompt, result

        Thread.current[:workflow_context] = nil
      end

      test "call method passes options correctly" do
        # Mock the run_claude_code method to verify it receives the correct options
        CodingAgent.expects(:run_claude_code).with(
          "Test prompt",
          include_context_summary: true,
          continue: true,
        ).returns("Success")

        result = CodingAgent.call("Test prompt", include_context_summary: true, continue: true)
        assert_equal "Success", result
      end

      test "build_options_string creates correct command line options" do
        options = { model: "opus", temperature: 0.7, verbose: true, quiet: false }
        result = CodingAgent.send(:build_options_string, options)
        assert_equal "--model opus --temperature 0.7 --verbose", result
      end

      test "build_command includes configured options" do
        CodingAgent.configured_options = { model: "opus" }
        base_command = "claude -p --verbose"
        result = CodingAgent.send(:build_command, base_command, continue: false)
        assert_equal "claude --model opus -p --verbose", result
      end

      test "build_command includes both configured options and continue flag" do
        CodingAgent.configured_options = { model: "opus", temperature: 0.5 }
        base_command = "claude -p --verbose"
        result = CodingAgent.send(:build_command, base_command, continue: true)
        assert_equal "claude --continue --model opus --temperature 0.5 -p --verbose", result
      end

      test "post_configuration_setup stores command and options separately" do
        config = {
          "coding_agent_command" => "custom-claude",
          "model" => "opus",
          "temperature" => 0.7,
        }

        CodingAgent.post_configuration_setup(nil, config)

        assert_equal "custom-claude", CodingAgent.configured_command
        assert_equal({ "model" => "opus", "temperature" => 0.7 }, CodingAgent.configured_options)
      end

      test "build_command handles non-standard commands with options" do
        CodingAgent.configured_options = { model: "opus" }
        base_command = "custom-claude-wrapper --some-flag"
        result = CodingAgent.send(:build_command, base_command, continue: false)
        assert_equal "custom-claude-wrapper --some-flag --model opus", result
      end

      test "build_command adds --resume flag with session_id when continue is true and session_id is provided" do
        base_command = "claude -p --verbose --output-format stream-json"
        session_id = "test-session-123"
        result = CodingAgent.send(:build_command, base_command, continue: true, session_id: session_id)
        assert_equal "claude --resume test-session-123 -p --verbose --output-format stream-json", result
      end

      test "build_command adds --continue flag when continue is true but no session_id" do
        base_command = "claude -p --verbose --output-format stream-json"
        result = CodingAgent.send(:build_command, base_command, continue: true, session_id: nil)
        assert_equal "claude --continue -p --verbose --output-format stream-json", result
      end

      test "build_command handles --resume with non-standard commands" do
        base_command = "custom-claude-wrapper --some-flag"
        session_id = "test-session-456"
        result = CodingAgent.send(:build_command, base_command, continue: true, session_id: session_id)
        assert_equal "custom-claude-wrapper --some-flag --resume test-session-456", result
      end

      test "build_command includes both configured options and resume flag" do
        CodingAgent.configured_options = { model: "opus", temperature: 0.5 }
        base_command = "claude -p --verbose"
        session_id = "test-session-789"
        result = CodingAgent.send(:build_command, base_command, continue: true, session_id: session_id)
        assert_equal "claude --resume test-session-789 --model opus --temperature 0.5 -p --verbose", result
      end

      test "call uses configured retries as default when not specified" do
        CodingAgent.configured_options = { "retries" => 2 }
        ENV["CLAUDE_CODE_COMMAND"] = "claude --output-format stream-json"

        # First two attempts fail
        mock_stdin1 = mock
        mock_stdout1 = StringIO.new("")
        mock_stderr1 = StringIO.new("Network error")
        mock_wait_thread1 = mock
        mock_status1 = mock
        mock_stdin1.expects(:close)
        mock_status1.expects(:success?).returns(false)
        mock_wait_thread1.expects(:value).returns(mock_status1)

        mock_stdin2 = mock
        mock_stdout2 = StringIO.new("")
        mock_stderr2 = StringIO.new("API timeout")
        mock_wait_thread2 = mock
        mock_status2 = mock
        mock_stdin2.expects(:close)
        mock_status2.expects(:success?).returns(false)
        mock_wait_thread2.expects(:value).returns(mock_status2)

        # Third attempt succeeds
        mock_output3 = [
          {
            type: "assistant",
            message: {
              content: [{ type: "text", text: "Task completed after retries" }],
            },
          }.to_json,
          { type: "result", subtype: "success", is_error: false, result: "Success on third attempt" }.to_json,
        ].join("\n")
        mock_stdin3 = mock
        mock_stdout3 = StringIO.new(mock_output3)
        mock_stderr3 = StringIO.new("")
        mock_wait_thread3 = mock
        mock_status3 = mock
        mock_stdin3.expects(:close)
        mock_status3.expects(:success?).returns(true)
        mock_wait_thread3.expects(:value).returns(mock_status3)

        # Expect exactly 3 calls (1 initial + 2 retries)
        Open3.expects(:popen3).times(3).with { |cmd| cmd =~ /cat .* \| claude --output-format stream-json$/ }
          .yields(mock_stdin1, mock_stdout1, mock_stderr1, mock_wait_thread1)
          .then.yields(mock_stdin2, mock_stdout2, mock_stderr2, mock_wait_thread2)
          .then.yields(mock_stdin3, mock_stdout3, mock_stderr3, mock_wait_thread3)

        # Call without specifying retries - should use configured default of 2
        result = CodingAgent.call("Test prompt")
        assert_equal "Success on third attempt", result
      end

      test "call parameter overrides configured retries" do
        CodingAgent.configured_options = { "retries" => 2 }
        ENV["CLAUDE_CODE_COMMAND"] = "claude --output-format stream-json"

        # First attempt fails
        mock_stdin1 = mock
        mock_stdout1 = StringIO.new("")
        mock_stderr1 = StringIO.new("Error")
        mock_wait_thread1 = mock
        mock_status1 = mock
        mock_stdin1.expects(:close)
        mock_status1.expects(:success?).returns(false)
        mock_wait_thread1.expects(:value).returns(mock_status1)

        # Second attempt succeeds
        mock_output2 = [
          {
            type: "assistant",
            message: {
              content: [{ type: "text", text: "Retrying task" }],
            },
          }.to_json,
          { type: "result", subtype: "success", is_error: false, result: "Success after retry" }.to_json,
        ].join("\n")

        mock_stdin2 = mock
        mock_stdout2 = StringIO.new(mock_output2)
        mock_stderr2 = StringIO.new("")
        mock_wait_thread2 = mock
        mock_status2 = mock
        mock_stdin2.expects(:close)
        mock_status2.expects(:success?).returns(true)
        mock_wait_thread2.expects(:value).returns(mock_status2)

        Open3.expects(:popen3).twice.with { |cmd| cmd =~ /cat .* \| claude --output-format stream-json$/ }
          .yields(mock_stdin1, mock_stdout1, mock_stderr1, mock_wait_thread1)
          .then.yields(mock_stdin2, mock_stdout2, mock_stderr2, mock_wait_thread2)

        # Call with explicit retries=1, should override the configured default of 2
        result = CodingAgent.call("Test prompt", retries: 1)
        assert_equal "Success after retry", result
      end

      test "call fails after exhausting all configured retries" do
        CodingAgent.configured_options = { "retries" => 2 }
        ENV["CLAUDE_CODE_COMMAND"] = "claude --output-format stream-json"

        # Create separate mocks for each attempt since stderr.read consumes the stream
        3.times do |i|
          mock_stdin = mock
          mock_stdout = StringIO.new("")
          mock_stderr = StringIO.new("Persistent error #{i + 1}")
          mock_wait_thread = mock
          mock_status = mock

          mock_stdin.expects(:close)
          mock_status.expects(:success?).returns(false)
          mock_wait_thread.expects(:value).returns(mock_status)

          Open3.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude --output-format stream-json$/ }
            .yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)
        end

        # Should fail with error message after all retries
        result = CodingAgent.call("Test prompt")
        assert_match(/Error running CodingAgent: Persistent error/, result)
      end

      test "default behavior is no retries when not configured" do
        # Clear any configured options
        CodingAgent.configured_options = {}
        ENV["CLAUDE_CODE_COMMAND"] = "claude --output-format stream-json"

        # Single attempt fails
        mock_stdin = mock
        mock_stdout = StringIO.new("")
        mock_stderr = StringIO.new("Command failed")
        mock_wait_thread = mock
        mock_status = mock

        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(false)
        mock_wait_thread.expects(:value).returns(mock_status)

        # Expect only ONE call (no retries)
        Open3.expects(:popen3).once.with { |cmd| cmd =~ /cat .* \| claude --output-format stream-json$/ }
          .yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        # Should fail immediately without retrying
        result = CodingAgent.call("Test prompt")
        assert_match(/Error running CodingAgent: Command failed/, result)
      end
    end
  end
end
