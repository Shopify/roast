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
end
