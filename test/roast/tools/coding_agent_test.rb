# frozen_string_literal: true

require "test_helper"

module Roast
  module Tools
    class CodingAgentTest < ActiveSupport::TestCase
      class DummyBaseClass
        class << self
          attr_accessor :registered_functions

          def function(name, description, **params, &block)
            @registered_functions ||= {}
            @registered_functions[name] = {
              description: description,
              params: params,
              block: block,
            }
          end
        end
      end

      setup do
        # Reset the configured command before each test
        Roast::Tools::CodingAgent.configured_command = nil
      end

      test "uses default command when no configuration is provided" do
        # Store original ENV value
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV.delete("CLAUDE_CODE_COMMAND")

        # Mock CmdRunner.popen3 to prevent actual command execution
        mock_stdin = mock
        mock_stdout = StringIO.new('{"type":"result","subtype":"success","result":"AI response"}')
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        Roast::Helpers::CmdRunner.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude -p --verbose --output-format stream-json --dangerously-skip-permissions$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal("AI response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "uses environment variable when set" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude --model opus"

        # Mock CmdRunner.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        Roast::Helpers::CmdRunner.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude --model opus$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal("AI response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "post_configuration_setup sets configured command" do
        config = { "coding_agent_command" => "claude --model opus -p --allowedTools \"Bash, Glob\"" }
        Roast::Tools::CodingAgent.post_configuration_setup(DummyBaseClass, config)

        assert_equal "claude --model opus -p --allowedTools \"Bash, Glob\"", Roast::Tools::CodingAgent.configured_command
      end

      test "uses configured command from post_configuration_setup" do
        config = { "coding_agent_command" => "claude --model opus -p --allowedTools \"Bash, Batch, Glob, Grep, LS, Read\"" }
        Roast::Tools::CodingAgent.post_configuration_setup(DummyBaseClass, config)

        # Mock CmdRunner.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response with custom config")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        expected_command = /cat .* \| claude --model opus -p --allowedTools "Bash, Batch, Glob, Grep, LS, Read"$/
        Roast::Helpers::CmdRunner.expects(:popen3).with { |cmd| cmd =~ expected_command }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal "AI response with custom config", result
      end

      test "configuration takes precedence over environment variable" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude --model haiku"

        config = { "coding_agent_command" => "claude --model opus" }
        Roast::Tools::CodingAgent.post_configuration_setup(DummyBaseClass, config)

        # Mock CmdRunner.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        # Should use configured command, not environment variable
        Roast::Helpers::CmdRunner.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude --model opus$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal("AI response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "handles command execution errors gracefully" do
        # Mock CmdRunner.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("")
        mock_stderr = StringIO.new("Command not found: claude")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(false)
        mock_wait_thread.expects(:value).returns(mock_status)

        Roast::Helpers::CmdRunner.expects(:popen3).yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal "🤖 Error running CodingAgent: Command not found: claude", result
      end

      test "cleans up temporary files even on error" do
        # Force an error during command execution
        Roast::Helpers::CmdRunner.expects(:popen3).raises(Roast::Error, "Execution failed")

        # Track temp file creation and deletion
        tempfile_deleted = false

        Tempfile.any_instance.stubs(:write)
        Tempfile.any_instance.stubs(:close)
        Tempfile.any_instance.stubs(:path).returns("/tmp/test_file.txt")

        # Monitor tempfile lifecycle
        Tempfile.any_instance.expects(:unlink).at_least_once.with do
          tempfile_deleted = true
          true
        end

        result = Roast::Tools::CodingAgent.call("Test prompt")

        assert_match(/Error running CodingAgent/, result)
        assert tempfile_deleted, "Temporary file should be cleaned up even on error"
      end

      test "runs Claude with simple prompt and gets simple result" do
        skip "Testing with actual Claude is expensive"

        # Use a prompt that should hopefully work pretty consistently on each invocation
        prompt = "What is today's date, in yyyy-mm-dd format?"
        result = Roast::Tools::CodingAgent.call(prompt)
        assert_includes(result, Date.today.strftime("%Y-%m-%d"))
      end

      test "logs streaming output with sensible formatting" do
        # NOTE: the command must include '--output-format stream-json' for the coding agent to expect streaming json responses.
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "cat test/fixtures/tools/coding_agent/simple_responses.json_stream # --output-format stream-json"

        expected_log_messages = [
          "🤖 Running CodingAgent\n",
          "• 	→ Read(\"path/to/README.md\")\n",
          "• 	→ Read(\"path/to/file.gemspec\")\n",
          "• 	→ Read(\"path/to/file.rb\")\n",
          "• \tLorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur porttitor ac nisi in mollis. ... lots more text ...\n",
        ]

        Roast::Helpers::Logger.instance.logger.expects(:info).times(expected_log_messages.length).with do |actual|
          puts actual # This is intentional to ensure that logger output is propagated to the console
          actual == expected_log_messages.shift
        end

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal(result, "RESULT TEXT")
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "handles formatting of more cases" do
        # NOTE: the command must include '--output-format stream-json' for the coding agent to expect streaming json responses.
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "cat test/fixtures/tools/coding_agent/complex_responses.json_stream # --output-format stream-json"

        expected_log_messages_file = "test/fixtures/tools/coding_agent/complex_responses.expected_log"
        expected_log_messages = File.readlines(expected_log_messages_file).map { |line| JSON.parse(line) }

        Roast::Helpers::Logger.instance.logger.expects(:info).times(expected_log_messages.length).with do |actual|
          puts actual # This is intentional to ensure that logger output is propagated to the console
          actual == expected_log_messages.shift
        end

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal(result, "RESULT TEXT")
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "handles failure when error result returned in json stream" do
        # NOTE: the command must include '--output-format stream-json' for the coding agent to expect streaming json responses.
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "cat test/fixtures/tools/coding_agent/error_result.json_stream # --output-format stream-json"

        expected_log_messages = [
          "🤖 Running CodingAgent\n",
          "• 	→ Read(\"path/to/README.md\")\n",
          "• 	→ Read(\"path/to/file.gemspec\")\n",
          "• 	→ Read(\"path/to/file.rb\")\n",
          "• \tLorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur porttitor ac nisi in mollis. ... lots more text ...\n",
        ]

        Roast::Helpers::Logger.instance.logger.expects(:info).times(expected_log_messages.length).with do |actual|
          puts actual # This is intentional to ensure that logger output is propagated to the console
          actual == expected_log_messages.shift
        end

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_match(/^🤖 Error running CodingAgent:/, result)
        assert_match(/"type"/, result)
        assert_match(/"result"/, result)
        assert_match(/"subtype"/, result)
        assert_match(/"success"/, result)
        assert_match(/"is_error"/, result)
        assert_match(/true/, result)
        assert_match(/"result"/, result)
        assert_match(/ERROR TEXT/, result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "included method registers coding_agent function" do
        DummyBaseClass.registered_functions = {}
        Roast::Tools::CodingAgent.included(DummyBaseClass)

        assert DummyBaseClass.registered_functions.key?(:coding_agent)

        function_def = DummyBaseClass.registered_functions[:coding_agent]
        assert_equal "AI-powered coding agent that runs an instance of the Claude Code agent with the given prompt. If the agent is iterating on previous work, set continue to true.", function_def[:description]
        assert_equal "string", function_def[:params][:prompt][:type]
        assert_equal "The prompt to send to Claude Code", function_def[:params][:prompt][:description]
      end

      test "handle_session_info extracts and stores session_id from JSON" do
        # Mock MetadataAccess methods
        CodingAgent.expects(:set_current_step_metadata).with("coding_agent_session_id", "test-session-123")

        # Create JSON with session_id
        json = { "session_id" => "test-session-123" }

        # Call handle_session_info
        Roast::Tools::CodingAgent.send(:handle_session_info, json)
      end

      test "handle_session_info does nothing when no session_id in JSON" do
        # Create JSON without session_id
        json = { "type" => "assistant", "message" => "some message" }

        # Expect no call to set_current_step_metadata
        CodingAgent.expects(:set_current_step_metadata).never

        # Call handle_session_info
        Roast::Tools::CodingAgent.send(:handle_session_info, json)
      end

      test "run_claude_code uses session_id from metadata when continue is true" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude --output-format stream-json"

        # Mock MetadataAccess methods
        CodingAgent.expects(:current_step_name).returns("test_step").at_least_once
        CodingAgent.expects(:workflow_metadata).returns({
          "test_step" => {
            "coding_agent_session_id" => "existing-session-456",
          },
        }).at_least_once

        # Mock successful response
        mock_output = [
          { type: "result", subtype: "success", is_error: false, result: "Success with resume" }.to_json,
        ].join("\n")
        mock_stdin = mock
        mock_stdout = StringIO.new(mock_output)
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        # Expect command with --resume flag
        Roast::Helpers::CmdRunner.expects(:popen3).with { |cmd| cmd =~ /claude --resume existing-session-456 --output-format stream-json$/ }
          .yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.send(:run_claude_code, "Test prompt", include_context_summary: false, continue: true)
        assert_equal("Success with resume", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "run_claude_code clears session_id when not using JSON formatting" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude"

        # Mock MetadataAccess methods
        CodingAgent.expects(:set_current_step_metadata).with("coding_agent_session_id", nil)

        # Mock successful response (non-JSON)
        mock_stdin = mock
        mock_stdout = StringIO.new("Plain text response")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        Roast::Helpers::CmdRunner.expects(:popen3).yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.send(:run_claude_code, "Test prompt", include_context_summary: false, continue: false)
        assert_equal("Plain text response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end
    end
  end
end
