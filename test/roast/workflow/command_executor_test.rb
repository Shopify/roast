# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class CommandExecutorTest < ActiveSupport::TestCase
      def setup
        @executor = CommandExecutor.new
      end

      def test_successful_command_execution
        result = @executor.execute("$(echo 'Hello World')")
        assert_equal("Hello World\n", result)
      end

      def test_command_with_exit_status_zero
        result = @executor.execute("$(exit 0)")
        assert_equal("", result)
      end

      def test_command_fails_by_default
        error = assert_raises(CommandExecutor::CommandExecutionError) do
          @executor.execute("$(exit 1)")
        end

        assert_equal("Command exited with non-zero status (1)", error.message)
        assert_equal("exit 1", error.command)
        assert_equal(1, error.exit_status)
      end

      def test_command_continues_with_exit_on_error_false
        result = @executor.execute("$(exit 42)", exit_on_error: false)

        assert_match(/\[Exit status: 42\]/, result)
      end

      def test_command_output_includes_stdout_and_exit_status
        result = @executor.execute("$(echo 'Error: Something went wrong' && exit 1)", exit_on_error: false)

        assert_match(/Error: Something went wrong/, result)
        assert_match(/\[Exit status: 1\]/, result)
      end

      def test_successful_command_with_exit_on_error_false
        result = @executor.execute("$(echo 'Success')", exit_on_error: false)

        assert_equal("Success\n", result)
        refute_match(/\[Exit status:/, result)
      end

      def test_invalid_command_format_raises_argument_error
        assert_raises(ArgumentError) do
          @executor.execute("echo 'Hello'")
        end
      end

      def test_command_not_found_with_exit_on_error_true
        error = assert_raises(CommandExecutor::CommandExecutionError) do
          @executor.execute("$(this_command_does_not_exist_12345)")
        end

        assert_match(/Failed to execute command/, error.message)
        assert_equal("this_command_does_not_exist_12345", error.command)
      end

      def test_command_not_found_with_exit_on_error_false
        result = @executor.execute("$(this_command_does_not_exist_12345)", exit_on_error: false)

        assert_match(/Error executing command:/, result)
        assert_match(/\[Exit status: error\]/, result)
      end

      def test_logger_receives_warning_when_continuing_after_error
        logger = mock("Logger")
        executor = CommandExecutor.new(logger: logger)

        logger.expects(:warn).with(regexp_matches(/Command 'exit 3' exited with non-zero status \(3\), continuing execution/))

        executor.execute("$(exit 3)", exit_on_error: false)
      end

      def test_logger_receives_warning_for_command_error
        logger = mock("Logger")
        executor = CommandExecutor.new(logger: logger)

        logger.expects(:warn).with(regexp_matches(/Command 'this_command_does_not_exist_12345' failed with error:/))

        executor.execute("$(this_command_does_not_exist_12345)", exit_on_error: false)
      end

      def test_complex_command_with_pipes_and_redirects
        result = @executor.execute("$(echo 'test' | grep 'test')")
        assert_equal("test\n", result)
      end

      def test_command_with_environment_variables
        result = @executor.execute("$(FOO=bar bash -c 'echo $FOO')")
        assert_equal("bar\n", result)
      end

      def test_multiline_command_execution
        multiline_command = '$(echo "line one
line two
line three")'

        result = @executor.execute(multiline_command)

        # echo outputs the string with actual newlines
        expected_output = "line one\nline two\nline three\n"
        assert_equal(expected_output, result)
      end

      def test_multiline_command_with_quotes
        multiline_command = '$(cat << "EOF"
line one
line two with "quotes"
line three
EOF
)'

        result = @executor.execute(multiline_command)

        expected_output = "line one\nline two with \"quotes\"\nline three\n"
        assert_equal(expected_output, result)
      end

      def test_multiline_command_with_complex_formatting
        multiline_command = '$(echo "First line
Second line with $(date +%Y)
Third line")'

        result = @executor.execute(multiline_command)

        # Should contain the multiline output with the year substituted
        assert_match(/First line/, result)
        assert_match(/Second line with \d{4}/, result) # matches year
        assert_match(/Third line/, result)
        assert_equal(3, result.split("\n").length)
      end

      def test_multiline_command_with_backticks
        multiline_command = '$(echo "Code example:
\\`function test() {\\`
\\`  return true;\\`
\\`}\\`")'

        result = @executor.execute(multiline_command)

        # Should contain the multiline output with backticks preserved
        assert_match(/Code example:/, result)
        assert_match(/`function test\(\) \{`/, result)
        assert_match(/`  return true;`/, result)
        assert_match(/`\}`/, result)
        assert_equal(4, result.split("\n").length)
      end
    end
  end
end
