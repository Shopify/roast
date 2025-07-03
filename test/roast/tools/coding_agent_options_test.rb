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
          resume: nil,
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

      test "call method passes resume option correctly" do
        # Mock the run_claude_code method to verify it receives the resume option
        CodingAgent.expects(:run_claude_code).with(
          "Test prompt",
          include_context_summary: false,
          continue: false,
          resume: "previous_step",
        ).returns("Success")

        result = CodingAgent.call("Test prompt", resume: "previous_step")
        assert_equal "Success", result
      end

      test "build_command handles resume with session ID" do
        base_command = "claude -p --verbose --output-format stream-json"
        result = CodingAgent.send(:build_command, base_command, continue: false, session_id: "test-session-123")
        assert_equal "claude --resume test-session-123 -p --verbose --output-format stream-json", result
      end

      test "build_command prefers session_id over continue" do
        base_command = "claude -p --verbose --output-format stream-json"
        result = CodingAgent.send(:build_command, base_command, continue: true, session_id: "test-session-123")
        assert_equal "claude --resume test-session-123 -p --verbose --output-format stream-json", result
      end

      test "build_command handles resume with non-standard commands" do
        base_command = "custom-claude-wrapper --some-flag"
        result = CodingAgent.send(:build_command, base_command, continue: false, session_id: "test-session-456")
        assert_equal "custom-claude-wrapper --some-flag --resume test-session-456", result
      end

      test "resolve_session_id returns nil when no workflow context" do
        Thread.current[:workflow_context] = nil
        result = CodingAgent.send(:resolve_session_id, "test_step")
        assert_nil result
      end

      test "resolve_session_id returns session ID from step output" do
        # Create mock workflow with step output containing session ID
        workflow = mock
        workflow.stubs(:output).returns({
          "test_step" => { "session_id" => "test-session-789", "content" => "step result" },
        })

        context = mock
        context.stubs(:workflow).returns(workflow)
        Thread.current[:workflow_context] = context

        result = CodingAgent.send(:resolve_session_id, "test_step")
        assert_equal "test-session-789", result

        Thread.current[:workflow_context] = nil
      end

      test "resolve_session_id returns nil when step has no session ID" do
        # Create mock workflow with step output but no session ID
        workflow = mock
        workflow.stubs(:output).returns({
          "test_step" => { "content" => "step result" },
        })

        context = mock
        context.stubs(:workflow).returns(workflow)
        Thread.current[:workflow_context] = context

        result = CodingAgent.send(:resolve_session_id, "test_step")
        assert_nil result

        Thread.current[:workflow_context] = nil
      end

      test "resolve_session_id returns nil when step output is not a hash" do
        # Create mock workflow with string step output
        workflow = mock
        workflow.stubs(:output).returns({
          "test_step" => "just a string result",
        })

        context = mock
        context.stubs(:workflow).returns(workflow)
        Thread.current[:workflow_context] = context

        result = CodingAgent.send(:resolve_session_id, "test_step")
        assert_nil result

        Thread.current[:workflow_context] = nil
      end

      test "store_session_id stores session ID in specified step output" do
        # Create mock workflow with empty output
        workflow = mock
        output_hash = {}
        workflow.stubs(:output).returns(output_hash)

        context = mock
        context.stubs(:workflow).returns(workflow)
        Thread.current[:workflow_context] = context
        Thread.current[:current_step_name] = "current_step"

        CodingAgent.send(:store_session_id, "new-session-123")

        assert_equal "new-session-123", output_hash["current_step"]["session_id"]

        Thread.current[:workflow_context] = nil
        Thread.current[:current_step_name] = nil
      end

      test "store_session_id converts string output to hash with session ID" do
        # Create mock workflow with existing string output
        workflow = mock
        output_hash = { "current_step" => "existing content" }
        workflow.stubs(:output).returns(output_hash)

        context = mock
        context.stubs(:workflow).returns(workflow)
        Thread.current[:workflow_context] = context
        Thread.current[:current_step_name] = "current_step"

        CodingAgent.send(:store_session_id, "new-session-456")

        expected_output = {
          "content" => "existing content",
          "session_id" => "new-session-456",
        }
        assert_equal expected_output, output_hash["current_step"]

        Thread.current[:workflow_context] = nil
        Thread.current[:current_step_name] = nil
      end

      test "current_step_name returns step name from thread storage" do
        Thread.current[:current_step_name] = "test_step"
        result = CodingAgent.send(:current_step_name)
        assert_equal "test_step", result

        Thread.current[:current_step_name] = nil
      end

      test "current_step_name returns nil when no step name set" do
        Thread.current[:current_step_name] = nil
        result = CodingAgent.send(:current_step_name)
        assert_nil result
      end
    end
  end
end
