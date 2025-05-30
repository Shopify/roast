# frozen_string_literal: true

require "test_helper"

module Roast
  module Tools
    class CmdTest < ActiveSupport::TestCase
      test "executes default allowed commands" do
        result = Roast::Tools::Cmd.call("pwd")
        assert_match(/Command: pwd/, result)
        assert_match(/Exit status: 0/, result)
        assert_match(/Output:/, result)
      end

      test "rejects disallowed commands with default configuration" do
        result = Roast::Tools::Cmd.call("echo 'test'")
        assert_equal "Error: Command not allowed. Only commands starting with pwd, find, ls, rake, ruby, dev, mkdir are permitted.", result
      end

      test "allows custom commands when configured" do
        config = { "allowed_commands" => ["echo"] }
        result = Roast::Tools::Cmd.call("echo 'hello world'", config)
        assert_match(/Command: echo 'hello world'/, result)
        assert_match(/Exit status: 0/, result)
        assert_match(/hello world/, result)
      end

      test "custom configuration overrides defaults completely" do
        config = { "allowed_commands" => ["echo"] }
        result = Roast::Tools::Cmd.call("pwd", config)
        assert_equal "Error: Command not allowed. Only commands starting with echo are permitted.", result
      end

      test "validates commands using exact prefix matching" do
        config = { "allowed_commands" => ["git"] }

        # git should work
        result = Roast::Tools::Cmd.call("git status", config)
        assert_match(/Command: git status/, result)
        refute_match(/Error: Command not allowed/, result)

        # gitk should not work (doesn't match exactly)
        result = Roast::Tools::Cmd.call("gitk", config)
        assert_equal "Error: Command not allowed. Only commands starting with git are permitted.", result
      end

      test "handles empty configuration gracefully" do
        result = Roast::Tools::Cmd.call("ls", {})
        assert_match(/Command: ls/, result)
        assert_match(/Exit status: 0/, result)
      end

      test "handles nil configuration gracefully" do
        result = Roast::Tools::Cmd.call("pwd")
        assert_match(/Command: pwd/, result)
        assert_match(/Exit status: 0/, result)
      end

      test "handles command execution errors" do
        config = { "allowed_commands" => ["false"] }
        result = Roast::Tools::Cmd.call("false", config)
        assert_match(/Command: false/, result)
        assert_match(/Exit status: 1/, result)
      end

      test "handles non-existent commands" do
        config = { "allowed_commands" => ["nonexistent_command_xyz"] }
        result = Roast::Tools::Cmd.call("nonexistent_command_xyz", config)
        assert_match(/Error running command:/, result)
      end

      test "formats output correctly" do
        config = { "allowed_commands" => ["echo"] }
        result = Roast::Tools::Cmd.call("echo 'test'", config)

        lines = result.split("\n")
        assert_match(/^Command: echo 'test'$/, lines[0])
        assert_match(/^Exit status: \d+$/, lines[1])
        assert_equal "Output:", lines[2]
        assert_match(/test/, lines[3])
      end

      test "includes all expected default commands" do
        expected_commands = ["pwd", "find", "ls", "rake", "ruby", "dev", "mkdir"]
        expected_commands.each do |cmd|
          # Test that each default command is allowed by trying to execute it with a safe argument
          test_command = case cmd
          when "find"
            "find . -maxdepth 0" # Safe find command that won't recurse
          when "ruby"
            "ruby -v" # Just show version
          when "rake"
            "rake --version" # Just show version
          when "dev"
            "dev version" # Assuming dev has a version command
          else
            cmd # pwd, ls, mkdir work without arguments
          end

          result = Roast::Tools::Cmd.call(test_command)
          refute_match(/Error: Command not allowed/, result, "Expected '#{cmd}' to be allowed in default configuration, but it was rejected")
        end
      end
    end
  end
end
