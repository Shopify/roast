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

      test "post_configuration_setup registers individual command functions" do
        DummyBaseClass.registered_functions = {}

        config = { "allowed_commands" => ["ls", "pwd", "git"] }
        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)

        # Check that functions were registered
        assert DummyBaseClass.registered_functions.key?(:ls)
        assert DummyBaseClass.registered_functions.key?(:pwd)
        assert DummyBaseClass.registered_functions.key?(:git)

        # Check descriptions
        assert_equal "ls command - list directory contents with options like -la, -R", DummyBaseClass.registered_functions[:ls][:description]
        assert_equal "pwd command - print current working directory path", DummyBaseClass.registered_functions[:pwd][:description]
        assert_equal "Execute the git command", DummyBaseClass.registered_functions[:git][:description]

        # Check params
        assert_equal "string", DummyBaseClass.registered_functions[:ls][:params][:args][:type]
        assert_equal false, DummyBaseClass.registered_functions[:ls][:params][:args][:required]
      end

      test "post_configuration_setup uses default commands when no config provided" do
        DummyBaseClass.registered_functions = {}

        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, {})

        # Check that default functions were registered
        assert DummyBaseClass.registered_functions.key?(:pwd)
        assert DummyBaseClass.registered_functions.key?(:find)
        assert DummyBaseClass.registered_functions.key?(:ls)
        assert DummyBaseClass.registered_functions.key?(:rake)
        assert DummyBaseClass.registered_functions.key?(:ruby)
        assert DummyBaseClass.registered_functions.key?(:dev)
        assert DummyBaseClass.registered_functions.key?(:mkdir)
      end

      test "individual command functions execute correctly" do
        DummyBaseClass.registered_functions = {}

        config = { "allowed_commands" => ["ls"] }
        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)

        # Get the ls function block
        ls_function = DummyBaseClass.registered_functions[:ls][:block]

        # Test with no args
        result = ls_function.call({ args: nil })
        assert_match(/Command: ls/, result)
        assert_match(/Exit status:/, result)

        # Test with args
        result = ls_function.call({ args: "-la" })
        assert_match(/Command: ls -la/, result)
        assert_match(/Exit status:/, result)
      end

      test "post_configuration_setup accepts hash format with custom descriptions" do
        DummyBaseClass.registered_functions = {}

        config = {
          "allowed_commands" => [
            "ls",
            { "name" => "git", "description" => "Custom git description for version control" },
            { "name" => "node", "description" => "Node.js package manager for dependencies" },
          ],
        }
        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)

        # Check that functions were registered
        assert DummyBaseClass.registered_functions.key?(:ls)
        assert DummyBaseClass.registered_functions.key?(:git)
        assert DummyBaseClass.registered_functions.key?(:node)

        # Check descriptions
        assert_equal "ls command - list directory contents with options like -la, -R", DummyBaseClass.registered_functions[:ls][:description]
        assert_equal "Custom git description for version control", DummyBaseClass.registered_functions[:git][:description]
        assert_equal "Node.js package manager for dependencies", DummyBaseClass.registered_functions[:node][:description]
      end

      test "post_configuration_setup accepts symbol keys in hash format" do
        DummyBaseClass.registered_functions = {}

        config = {
          "allowed_commands" => [
            { name: "docker", description: "Container management tool" },
          ],
        }
        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)

        assert DummyBaseClass.registered_functions.key?(:docker)
        assert_equal "Container management tool", DummyBaseClass.registered_functions[:docker][:description]
      end

      test "post_configuration_setup raises error for invalid hash format" do
        DummyBaseClass.registered_functions = {}

        config = {
          "allowed_commands" => [
            { "description" => "Missing name field" },
          ],
        }

        assert_raises(ArgumentError) do
          Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)
        end
      end

      test "validate_command works with mixed format allowed_commands" do
        config = {
          "allowed_commands" => [
            "pwd",
            { "name" => "git", "description" => "Version control" },
            { "name" => "node" },
          ],
        }

        # These should work
        result = Roast::Tools::Cmd.call("pwd", config)
        refute_match(/Error: Command not allowed/, result)

        result = Roast::Tools::Cmd.call("git status", config)
        refute_match(/Error: Command not allowed/, result)

        result = Roast::Tools::Cmd.call("node -v", config)
        refute_match(/Error: Command not allowed/, result)

        # This should fail
        result = Roast::Tools::Cmd.call("rm file.txt", config)
        assert_equal "Error: Command not allowed. Only commands starting with pwd, git, node are permitted.", result
      end

      test "included method does not register any functions" do
        DummyBaseClass.registered_functions = {}

        Roast::Tools::Cmd.included(DummyBaseClass)

        # Should not register any functions in included
        assert_empty DummyBaseClass.registered_functions
      end

      # Timeout functionality tests
      test "cmd tool hanging command simulation" do
        hanging_command = "sed 's/foo/bar/g'"

        result = Roast::Tools::Cmd.call(hanging_command)

        assert_match(/Error: Command not allowed/, result)
      end

      test "cmd tool timeout with ruby sleep" do
        start_time = Time.now

        result = Roast::Tools::Cmd.call("ruby -e 'sleep 2'", timeout: 1)

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert(elapsed_time < 10, "Command should timeout within reasonable time, but took #{elapsed_time} seconds")
        assert_match(/timed out after 1 seconds/, result)
      end

      test "cmd tool timeout with quick find command" do
        start_time = Time.now

        result = Roast::Tools::Cmd.call("find . -maxdepth 2 -name '*.rb' | head -5", timeout: 5)

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert(elapsed_time < 3, "Quick find should complete in under 3 seconds")
        assert(result.include?("Command: find"))
        assert(result.include?("Exit status:"))
        refute_match(/timed out/, result)
      end

      test "cmd tool with timeout parameter quick command" do
        result = Roast::Tools::Cmd.call("pwd", timeout: 5)

        assert(result.include?("Command: pwd"))
        assert(result.include?("Exit status: 0"))
        assert(result.include?("Output:"))
        refute_match(/timed out/, result)

        result_default = Roast::Tools::Cmd.call("pwd")

        assert(result_default.include?("Command: pwd"))
        assert(result_default.include?("Exit status: 0"))
        refute_match(/timed out/, result_default)
      end

      test "cmd tool timeout with ruby infinite loop" do
        start_time = Time.now

        result = Roast::Tools::Cmd.call("ruby -e 'loop { sleep(0.1) }'", timeout: 1)

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert(elapsed_time < 10, "Command should timeout within reasonable time, but took #{elapsed_time} seconds")
        assert_match(/timed out after 1 seconds/, result)
      end

      test "timeout prevents infinite hangs" do
        start_time = Time.now

        result = Roast::Tools::Cmd.call("ruby -e 'sleep 10'", timeout: 2)

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert(elapsed_time < 15, "Timeout should prevent infinite hangs - took #{elapsed_time} seconds")
        assert_match(/timed out after 2 seconds/, result)
        assert(result.is_a?(String), "Should return error message, not hang")
        assert_match(/timed out/, result)
      end

      test "timeout functionality exists" do
        result_with_timeout = Roast::Tools::Cmd.call("pwd", timeout: 30)
        result_without_timeout = Roast::Tools::Cmd.call("pwd")

        assert(result_with_timeout.include?("Command: pwd"))
        assert(result_without_timeout.include?("Command: pwd"))

        refute_match(/timed out/, result_with_timeout)
        refute_match(/timed out/, result_without_timeout)
      end

      test "timeout validation bounds" do
        result = Roast::Tools::Cmd.call("pwd", timeout: 9999)
        assert(result.include?("Command: pwd"))
        assert(result.include?("Exit status: 0"))
      end

      test "timeout validation edge cases" do
        result = Roast::Tools::Cmd.call("pwd", timeout: nil)
        assert(result.include?("Command: pwd"))
        assert(result.include?("Exit status: 0"))

        result = Roast::Tools::Cmd.call("pwd", timeout: -5)
        assert(result.include?("Command: pwd"))
        assert(result.include?("Exit status: 0"))

        result = Roast::Tools::Cmd.call("pwd", timeout: 0)
        assert(result.include?("Command: pwd"))
        assert(result.include?("Exit status: 0"))
      end

      test "thread safety exit status" do
        results = []
        threads = []

        5.times do |i|
          threads << Thread.new do
            if i.even?
              result = Roast::Tools::Cmd.call("pwd", timeout: 2)
              results << { thread: i, success: result.include?("Exit status: 0") }
            else
              result = Roast::Tools::Cmd.call("ls /nonexistent_path_#{i} 2>/dev/null", timeout: 2)
              results << { thread: i, success: result.include?("Exit status: 0") }
            end
          end
        end

        threads.each(&:join)

        success_count = results.count { |r| r[:success] }
        failure_count = results.count { |r| !r[:success] }

        assert(success_count >= 2, "Should have successful commands")
        assert(failure_count >= 2, "Should have failed commands")
      end

      test "resource cleanup on timeout" do
        start_time = Time.now

        result = Roast::Tools::Cmd.call("ruby -e 'puts Process.pid; sleep 10'", timeout: 1)

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert(elapsed_time < 5, "Should cleanup quickly after timeout")
        assert_match(/timed out after 1 seconds/, result)
      end

      test "dev command shell escaping with timeout" do
        script_content = <<~SCRIPT
          #!/bin/bash
          echo "Executed with args: $@"
          echo "Shell: $0"
        SCRIPT

        File.write("/tmp/fake_dev", script_content)
        File.chmod(0o755, "/tmp/fake_dev")

        config = { "allowed_commands" => ["/tmp/fake_dev"] }

        begin
          result = Roast::Tools::Cmd.call("/tmp/fake_dev echo 'hello world'", config, timeout: 5)

          assert(result.include?("Command: /tmp/fake_dev echo 'hello world'"))
          assert(result.include?("Exit status: 0"))
          assert(result.include?("hello world"))
        ensure
          File.delete("/tmp/fake_dev") if File.exist?("/tmp/fake_dev")
        end
      end

      test "command prefix dev detection" do
        config = { "allowed_commands" => ["dev"] }

        result = Roast::Tools::Cmd.call("dev help", config, timeout: 1)

        assert(result.include?("Command: dev help"))
        assert(result.include?("command not found"))
      end

      test "quote escaping in bash command" do
        config = { "allowed_commands" => ["echo"] }

        result = Roast::Tools::Cmd.call("echo \"it's working\"", config, timeout: 5)

        assert(result.include?("Exit status: 0"))
        assert(result.include?("it's working"))
      end

      test "timeout path vs non timeout path consistency" do
        config = { "allowed_commands" => ["echo"] }

        result_without_timeout = Roast::Tools::Cmd.call("echo 'test'", config)
        result_with_timeout = Roast::Tools::Cmd.call("echo 'test'", config, timeout: 5)

        assert(result_without_timeout.include?("Exit status: 0"))
        assert(result_with_timeout.include?("Exit status: 0"))
        assert(result_without_timeout.include?("test"))
        assert(result_with_timeout.include?("test"))
      end

      test "process kill error handling" do
        config = { "allowed_commands" => ["ruby"] }

        result = Roast::Tools::Cmd.call("ruby -e 'exit 0'", config, timeout: 1)

        assert(result.include?("Exit status: 0"))
      end

      test "execute allowed command with standard error" do
        config = { "allowed_commands" => ["ruby"] }

        result = Roast::Tools::Cmd.execute_allowed_command("ruby -e 'raise \"test error\"'", "ruby", 5)

        assert(result.is_a?(String))
        assert(result.include?("Exit status: 1"))
      end

      test "call method with standard error handling" do
        config = { "allowed_commands" => ["nonexistent_command_xyz"] }

        result = Roast::Tools::Cmd.call("nonexistent_command_xyz", config, timeout: 1)

        assert(result.is_a?(String))
        assert(result.include?("Error running command") || result.include?("command not found"))
      end

      # Output formatting tests
      test "formats output consistently" do
        result = Roast::Tools::Cmd.call("pwd")

        assert_match(/Command: pwd/, result)
        assert_match(/Exit status: 0/, result)
        assert_match(/Output:\n/, result)
        assert_includes(result, Dir.pwd)
      end

      test "formats output with custom commands" do
        config = { "allowed_commands" => ["echo"] }
        result = Roast::Tools::Cmd.call("echo 'test output'", config)

        assert_match(/Command: echo 'test output'/, result)
        assert_match(/Exit status: 0/, result)
        assert_match(/Output:\ntest output/, result)
      end

      test "formats output with non-zero exit status" do
        config = { "allowed_commands" => ["ruby"] }
        result = Roast::Tools::Cmd.call("ruby -e 'exit 1'", config)

        assert_match(/Command: ruby -e 'exit 1'/, result)
        assert_match(/Exit status: 1/, result)
        assert_match(/Output:/, result)
      end

      test "formats complex command output" do
        result = Roast::Tools::Cmd.call("find . -maxdepth 1 -name '*.rb' | head -1")

        assert_match(/Command: find/, result)
        assert_match(/Exit status:/, result)
        assert_match(/Output:/, result)
      end
    end
  end
end
