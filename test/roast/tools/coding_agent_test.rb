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

        # Mock Open3.popen3 to prevent actual command execution
        mock_stdin = mock
        mock_stdout = StringIO.new('{"type":"result","subtype":"success","result":"AI response"}')
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        Open3.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude -p --verbose --output-format stream-json --dangerously-skip-permissions$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal("AI response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "uses environment variable when set" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude --model opus"

        # Mock Open3.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        Open3.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude --model opus$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

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

        # Mock Open3.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response with custom config")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        expected_command = /cat .* \| claude --model opus -p --allowedTools "Bash, Batch, Glob, Grep, LS, Read"$/
        Open3.expects(:popen3).with { |cmd| cmd =~ expected_command }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal "AI response with custom config", result
      end

      test "configuration takes precedence over environment variable" do
        original_env = ENV["CLAUDE_CODE_COMMAND"]
        ENV["CLAUDE_CODE_COMMAND"] = "claude --model haiku"

        config = { "coding_agent_command" => "claude --model opus" }
        Roast::Tools::CodingAgent.post_configuration_setup(DummyBaseClass, config)

        # Mock Open3.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("AI response")
        mock_stderr = StringIO.new("")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(true)
        mock_wait_thread.expects(:value).returns(mock_status)

        # Should use configured command, not environment variable
        Open3.expects(:popen3).with { |cmd| cmd =~ /cat .* \| claude --model opus$/ }.yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal("AI response", result)
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "handles command execution errors gracefully" do
        # Mock Open3.popen3
        mock_stdin = mock
        mock_stdout = StringIO.new("")
        mock_stderr = StringIO.new("Command not found: claude")
        mock_wait_thread = mock
        mock_status = mock
        mock_stdin.expects(:close)
        mock_status.expects(:success?).returns(false)
        mock_wait_thread.expects(:value).returns(mock_status)

        Open3.expects(:popen3).yields(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)

        result = Roast::Tools::CodingAgent.call("Test prompt")
        assert_equal "Error running CodingAgent: Command not found: claude", result
      end

      test "cleans up temporary files even on error" do
        # Force an error during command execution
        Open3.expects(:popen3).raises(StandardError, "Execution failed")

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
        assert_equal(result, "Error running CodingAgent: ERROR TEXT")
      ensure
        ENV["CLAUDE_CODE_COMMAND"] = original_env
      end

      test "included method registers coding_agent function" do
        DummyBaseClass.registered_functions = {}
        Roast::Tools::CodingAgent.included(DummyBaseClass)

        assert DummyBaseClass.registered_functions.key?(:coding_agent)

        function_def = DummyBaseClass.registered_functions[:coding_agent]
        assert_equal "AI-powered coding agent that runs an instance of the Claude Code agent with the given prompt. If the agent is iterating on previous work, set continue to true. To resume from a specific previous session, set resume to the step name.", function_def[:description]
        assert_equal "string", function_def[:params][:prompt][:type]
        assert_equal "The prompt to send to Claude Code", function_def[:params][:prompt][:description]
      end
    end
  end
end
