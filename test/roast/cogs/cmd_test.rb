# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Cmd < Cog
      class ConfigTest < ActiveSupport::TestCase
        def setup
          @config = Config.new
        end

        # fail_on_error configuration tests
        test "fail_on_error? returns true by default" do
          assert @config.fail_on_error?
        end

        test "fail_on_error! sets fail_on_error to true" do
          @config.no_fail_on_error!
          @config.fail_on_error!

          assert @config.fail_on_error?
        end

        test "no_fail_on_error! sets fail_on_error to false" do
          @config.no_fail_on_error!

          refute @config.fail_on_error?
        end

        # show_stdout configuration tests
        test "show_stdout? returns false by default" do
          refute @config.show_stdout?
        end

        test "show_stdout! enables stdout display" do
          @config.show_stdout!

          assert @config.show_stdout?
        end

        test "no_show_stdout! disables stdout display" do
          @config.show_stdout!
          @config.no_show_stdout!

          refute @config.show_stdout?
        end

        # show_stderr configuration tests
        test "show_stderr? returns false by default" do
          refute @config.show_stderr?
        end

        test "show_stderr! enables stderr display" do
          @config.show_stderr!

          assert @config.show_stderr?
        end

        test "no_show_stderr! disables stderr display" do
          @config.show_stderr!
          @config.no_show_stderr!

          refute @config.show_stderr?
        end

        # display! and no_display! configuration tests
        test "display! enables both stdout and stderr" do
          @config.display!

          assert @config.show_stdout?
          assert @config.show_stderr?
        end

        test "no_display! disables both stdout and stderr" do
          @config.display!
          @config.no_display!

          refute @config.show_stdout?
          refute @config.show_stderr?
        end

        test "display? returns true when stdout is enabled" do
          @config.show_stdout!

          assert @config.display?
        end

        test "display? returns true when stderr is enabled" do
          @config.show_stderr!

          assert @config.display?
        end

        test "display? returns false when both are disabled" do
          @config.no_display!

          refute @config.display?
        end

        # Alias tests
        test "quiet! is alias for no_display!" do
          @config.display!
          @config.quiet!

          refute @config.show_stdout?
          refute @config.show_stderr?
        end
      end

      class InputTest < ActiveSupport::TestCase
        def setup
          @input = Input.new
        end

        # validate! tests
        test "validate! raises error when command is nil" do
          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'command' is required", error.message
        end

        test "validate! raises error when command is empty string" do
          @input.command = ""

          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'command' is required", error.message
        end

        test "validate! raises error when command is whitespace only" do
          @input.command = "   "

          error = assert_raises(Cog::Input::InvalidInputError) do
            @input.validate!
          end

          assert_equal "'command' is required", error.message
        end

        test "validate! succeeds when command is present" do
          @input.command = "echo"

          assert_nothing_raised do
            @input.validate!
          end
        end

        # coerce tests
        test "coerce sets command from string" do
          @input.coerce("ls -la")

          assert_equal "ls -la", @input.command
        end

        test "coerce sets command and args from array" do
          @input.coerce(["echo", "hello", "world"])

          assert_equal "echo", @input.command
          assert_equal ["hello", "world"], @input.args
        end

        test "coerce converts array elements to strings" do
          @input.coerce([:echo, 123, :test])

          assert_equal "echo", @input.command
          assert_equal ["123", "test"], @input.args
        end

        test "coerce does nothing for non-string non-array values" do
          @input.coerce(42)

          assert_nil @input.command
          assert_equal [], @input.args
        end

        test "coerce does nothing for nil" do
          @input.coerce(nil)

          assert_nil @input.command
          assert_equal [], @input.args
        end
      end

      class OutputTest < ActiveSupport::TestCase
        ProcessStatus = Struct.new(:exitstatus, :success, keyword_init: true) do
          def success?
            success
          end
        end

        def setup
          @status = ProcessStatus.new(exitstatus: 0, success: true)
        end

        test "initialize sets out, err, and status" do
          output = Output.new("stdout content", "stderr content", @status)

          assert_equal "stdout content", output.out
          assert_equal "stderr content", output.err
          assert_same @status, output.status
        end

        test "provides text parsing from stdout" do
          output = Output.new("  Test output  \n", "", @status)

          assert_equal "Test output", output.text
        end

        test "provides line parsing from stdout" do
          output = Output.new("  line1  \n  line2  ", "", @status)

          assert_equal ["line1", "line2"], output.lines
        end

        test "provides JSON parsing from stdout" do
          output = Output.new('{"key": "value"}', "", @status)

          assert_equal({ key: "value" }, output.json!)
        end

        test "provides safe JSON parsing from stdout" do
          output = Output.new("not json", "", @status)

          assert_nil output.json
        end

        test "provides float parsing from stdout" do
          output = Output.new("42.5", "", @status)

          assert_equal 42.5, output.float!
        end

        test "provides safe float parsing from stdout" do
          output = Output.new("not a number", "", @status)

          assert_nil output.float
        end

        test "provides integer parsing from stdout" do
          output = Output.new("42", "", @status)

          assert_equal 42, output.integer!
        end

        test "provides safe integer parsing from stdout" do
          output = Output.new("not a number", "", @status)

          assert_nil output.integer
        end
      end

      class ExecuteTest < ActiveSupport::TestCase
        test "run! executes command and captures stdout" do
          cog = Cmd.new(:echo_test, ->(_input, _scope, _index) { "echo hello world" })

          run_cog(cog)

          assert cog.succeeded?
          assert_equal "hello world", cog.output.text
        end

        test "run! executes command with arguments from array" do
          cog = Cmd.new(:echo_args, ->(_input, _scope, _index) { ["echo", "foo", "bar"] })

          run_cog(cog)

          assert cog.succeeded?
          assert_equal "foo bar", cog.output.text
        end

        test "run! marks cog as failed when command fails with fail_on_error" do
          cog = Cmd.new(:failing_cmd, ->(_input, _scope, _index) { "exit 1" })

          run_cog(cog)

          assert cog.failed?
        end

        test "run! succeeds when command fails with no_fail_on_error" do
          cog = Cmd.new(:failing_cmd, ->(_input, _scope, _index) { "exit 42" })
          config = Config.new
          config.no_fail_on_error!

          run_cog(cog, config: config)

          assert cog.succeeded?
          assert_equal 42, cog.output.status.exitstatus
        end

        test "run! captures stderr" do
          cog = Cmd.new(:stderr_test, ->(_input, _scope, _index) { "echo error >&2" })
          config = Config.new
          config.no_fail_on_error!

          run_cog(cog, config: config)

          assert cog.succeeded?
          assert_equal "error\n", cog.output.err
        end

        test "run! allows setting command via input block" do
          cog = Cmd.new(:input_block, ->(input, _scope, _index) {
            input.command = "echo"
            input.args = ["configured", "via", "input"]
          })

          run_cog(cog)

          assert cog.succeeded?
          assert_equal "configured via input", cog.output.text
        end
      end
    end
  end
end
