# frozen_string_literal: true

require "test_helper"

class RoastToolsBashTest < ActiveSupport::TestCase
  def setup
    @original_bash_warnings = ENV["ROAST_BASH_WARNINGS"]
    # Disable warnings for tests
    ENV["ROAST_BASH_WARNINGS"] = "false"
  end

  def teardown
    ENV["ROAST_BASH_WARNINGS"] = @original_bash_warnings
  end

  test "executes bash commands without restrictions" do
    result = Roast::Tools::Bash.call("echo 'Hello from Bash!'")
    assert_match(/Command: echo 'Hello from Bash!'/, result)
    assert_match(/Exit status: 0/, result)
    assert_match(/Hello from Bash!/, result)
  end

  test "executes complex commands with pipes" do
    result = Roast::Tools::Bash.call("echo 'line1\nline2\nline3' | grep 'line2'")
    assert_match(/Exit status: 0/, result)
    assert_match(/line2/, result)
  end

  test "returns non-zero exit status on failure" do
    result = Roast::Tools::Bash.call("false")
    assert_match(/Exit status: 1/, result)
  end

  test "handles command errors gracefully" do
    result = Roast::Tools::Bash.call("command_that_does_not_exist")
    # Command not found returns exit status 127
    assert_match(/Exit status: 127/, result)
    assert_match(/command_that_does_not_exist/, result)
    # The error message format varies by shell/OS
    assert_match(/not found|No such file/, result)
  end

  test "includes function dispatch when included" do
    base_class = Class.new do
      class << self
        def function(*args)
          # Mock function method
        end
      end
    end

    # Should not raise an error
    assert_nothing_raised do
      base_class.include(Roast::Tools::Bash)
    end
  end

  test "shows warning when warnings are enabled" do
    ENV["ROAST_BASH_WARNINGS"] = nil

    # Use mocha to verify the logger is called with warning
    Roast::Helpers::Logger.expects(:warn).with("⚠️  WARNING: Unrestricted bash execution - use with caution!\n").once

    Roast::Tools::Bash.call("pwd")
  end

  test "suppresses warning when ROAST_BASH_WARNINGS is false" do
    ENV["ROAST_BASH_WARNINGS"] = "false"

    # Use mocha to verify the logger is NOT called with warning
    Roast::Helpers::Logger.expects(:warn).never

    Roast::Tools::Bash.call("pwd")
  end

  test "executes commands that would be restricted by Cmd tool" do
    # Commands that Cmd tool would reject
    dangerous_commands = [
      "curl https://example.com",
      "rm -rf /tmp/test_file_that_does_not_exist",
      "ps aux",
      "chmod +x /tmp/nonexistent",
      "echo 'foo' | sed 's/foo/bar/g'",
      "echo 'hello world' | awk '{print $1}'",
      "echo 'test pattern' | grep 'pattern'",
    ]

    dangerous_commands.each do |cmd|
      result = Roast::Tools::Bash.call(cmd)
      # Should execute without "Command not allowed" error
      refute_match(/Command not allowed/, result)
      assert_match(/Exit status:/, result)
    end
  end

  test "handles multi-line output correctly" do
    result = Roast::Tools::Bash.call("echo -e 'line1\nline2\nline3'")
    assert_match(/line1/, result)
    assert_match(/line2/, result)
    assert_match(/line3/, result)
  end

  test "handles environment variables" do
    ENV["TEST_VAR"] = "hello"
    result = Roast::Tools::Bash.call("echo $TEST_VAR")
    assert_match(/hello/, result)
    ENV.delete("TEST_VAR") # Clean up after test
  end

  test "works with current directory" do
    result = Roast::Tools::Bash.call("pwd")
    assert_match(/Exit status: 0/, result)
    assert_match(Dir.pwd, result)
  end

  # Timeout functionality tests
  test "uses default timeout when none specified" do
    start_time = Time.now
    result = Roast::Tools::Bash.call("echo 'quick command'")
    elapsed = Time.now - start_time

    assert_operator elapsed, :<, 1.0
    assert_match(/Exit status: 0/, result)
    assert_match(/quick command/, result)
  end

  test "respects custom timeout parameter" do
    start_time = Time.now
    result = Roast::Tools::Bash.call("echo 'custom timeout'", timeout: 5)
    elapsed = Time.now - start_time

    assert_operator elapsed, :<, 1.0
    assert_match(/Exit status: 0/, result)
    assert_match(/custom timeout/, result)
  end

  test "times out long-running commands" do
    start_time = Time.now

    result = Roast::Tools::Bash.call("sleep 5", timeout: 1)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 2.0
    assert_match(/timed out after 1 seconds/, result)
  end

  test "handles timeout with complex commands" do
    start_time = Time.now

    result = Roast::Tools::Bash.call("sleep 3 && echo 'completed'", timeout: 1)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 2.0
    assert_match(/timed out after 1 seconds/, result)
    # Should not contain successful completion output
    refute_match(/Exit status: 0/, result)
    refute_match(/Output:\ncompleted/, result)
  end

  test "timeout prevents stdin hanging commands like sed without input" do
    start_time = Time.now

    result = Roast::Tools::Bash.call("sed 's/foo/bar/g'", timeout: 2)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 3.0
    # Should either timeout or exit quickly without hanging
    assert(elapsed < 3.0 || result.include?("timed out"))
  end

  test "timeout works with pipes and redirects" do
    start_time = Time.now

    result = Roast::Tools::Bash.call("sleep 4 | cat", timeout: 1)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 2.0
    assert_match(/timed out after 1 seconds/, result)
  end

  test "timeout validation uses TimeoutHandler defaults" do
    # Test that invalid timeout values are handled by TimeoutHandler validation
    output = Roast::Tools::Bash.call("echo 'test'", timeout: 0)

    assert_includes output, "test"
  end

  test "timeout error is logged properly" do
    # Mock the logger to verify timeout error logging
    Roast::Helpers::Logger.expects(:error).with(regexp_matches(/timed out after 1 seconds/)).once

    Roast::Tools::Bash.call("sleep 3", timeout: 1)
  end

  test "timeout accuracy is reasonable" do
    start_time = Time.now

    Roast::Tools::Bash.call("sleep 10", timeout: 1)

    elapsed = Time.now - start_time
    assert_operator elapsed, :>=, 0.9
    assert_operator elapsed, :<=, 1.6
  end

  test "quick commands complete before timeout" do
    start_time = Time.now

    result = Roast::Tools::Bash.call("echo 'fast'", timeout: 10)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 1.0
    assert_match(/Exit status: 0/, result)
    assert_match(/fast/, result)
  end

  test "timeout with zero disables timeout" do
    # TimeoutHandler should convert 0 to default timeout
    start_time = Time.now

    result = Roast::Tools::Bash.call("echo 'validated'", timeout: 0)

    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 1.0
    assert_match(/Exit status: 0/, result)
    assert_match(/validated/, result)
  end

  # Output formatting tests
  test "formats output consistently" do
    result = Roast::Tools::Bash.call("echo 'test output'")

    assert_match(/Command: echo 'test output'/, result)
    assert_match(/Exit status: 0/, result)
    assert_match(/Output:\ntest output/, result)
  end

  test "formats output with non-zero exit status" do
    result = Roast::Tools::Bash.call("bash -c 'echo error; exit 1'")

    assert_match(/Command: bash -c 'echo error; exit 1'/, result)
    assert_match(/Exit status: 1/, result)
    assert_match(/Output:\nerror/, result)
  end

  test "formats output with empty result" do
    result = Roast::Tools::Bash.call("true")

    assert_match(/Command: true/, result)
    assert_match(/Exit status: 0/, result)
    assert_match(/Output:\n$/, result)
  end

  test "formats complex command output" do
    command = "echo 'line1' && echo 'line2'"
    result = Roast::Tools::Bash.call(command)

    assert_match(/Command: #{Regexp.escape(command)}/, result)
    assert_match(/Exit status: 0/, result)
    assert_match(/line1/, result)
    assert_match(/line2/, result)
  end
end
