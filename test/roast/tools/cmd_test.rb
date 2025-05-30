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
            { "name" => "npm", "description" => "Node.js package manager for dependencies" },
          ],
        }
        Roast::Tools::Cmd.post_configuration_setup(DummyBaseClass, config)

        # Check that functions were registered
        assert DummyBaseClass.registered_functions.key?(:ls)
        assert DummyBaseClass.registered_functions.key?(:git)
        assert DummyBaseClass.registered_functions.key?(:npm)

        # Check descriptions
        assert_equal "ls command - list directory contents with options like -la, -R", DummyBaseClass.registered_functions[:ls][:description]
        assert_equal "Custom git description for version control", DummyBaseClass.registered_functions[:git][:description]
        assert_equal "Node.js package manager for dependencies", DummyBaseClass.registered_functions[:npm][:description]
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
            { "name" => "npm" },
          ],
        }

        # These should work
        result = Roast::Tools::Cmd.call("pwd", config)
        refute_match(/Error: Command not allowed/, result)

        result = Roast::Tools::Cmd.call("git status", config)
        refute_match(/Error: Command not allowed/, result)

        result = Roast::Tools::Cmd.call("npm install", config)
        refute_match(/Error: Command not allowed/, result)

        # This should fail
        result = Roast::Tools::Cmd.call("rm file.txt", config)
        assert_equal "Error: Command not allowed. Only commands starting with pwd, git, npm are permitted.", result
      end

      test "included method does not register any functions" do
        DummyBaseClass.registered_functions = {}

        Roast::Tools::Cmd.included(DummyBaseClass)

        # Should not register any functions in included
        assert_empty DummyBaseClass.registered_functions
      end
    end
  end
end
