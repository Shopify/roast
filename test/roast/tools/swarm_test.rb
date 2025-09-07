# frozen_string_literal: true

require "test_helper"

module Roast
  module Tools
    class SwarmTest < ActiveSupport::TestCase
      setup do
        # Reset tool config before each test
        Roast::Tools::Swarm.instance_variable_set(:@tool_config, nil)
      end

      test "call returns error when no config file is found" do
        # Mock that no default config files exist
        File.stub(:exist?, false) do
          result = Roast::Tools::Swarm.call("Test prompt")
          assert_match "Error: No swarm configuration file found", result
        end
      end

      test "call returns error when specified config file does not exist" do
        result = Roast::Tools::Swarm.call("Test prompt", "/nonexistent/path.yml")
        assert_match "Error: Swarm configuration file not found at:", result
        assert_match "/nonexistent/path.yml", result
      end

      test "post_configuration_setup stores tool config" do
        config = { "path" => "custom-swarm.yml", "other_option" => "value" }
        Roast::Tools::Swarm.post_configuration_setup(nil, config)

        assert_equal config, Roast::Tools::Swarm.tool_config
      end

      test "determine_config_path prioritizes step-level path" do
        # Set tool config
        Roast::Tools::Swarm.post_configuration_setup(nil, { "path" => "tool-config.yml" })

        # Private method test via send
        path = Roast::Tools::Swarm.send(:determine_config_path, "step-level.yml")
        assert_equal "step-level.yml", path
      end

      test "determine_config_path uses tool config when no step path" do
        # Set tool config
        Roast::Tools::Swarm.post_configuration_setup(nil, { "path" => "tool-config.yml" })

        # Private method test via send
        path = Roast::Tools::Swarm.send(:determine_config_path, nil)
        assert_equal "tool-config.yml", path
      end

      test "determine_config_path finds default config files" do
        # Mock that .swarm.yml exists
        File.stub(:exist?, ->(path) { path == ".swarm.yml" }) do
          path = Roast::Tools::Swarm.send(:determine_config_path, nil)
          assert_equal ".swarm.yml", path
        end
      end

      test "build_swarm_command escapes shell arguments properly" do
        command = Roast::Tools::Swarm.send(:build_swarm_command, 'Test with "quotes" and $vars', "config.yml")

        # Check the command is properly escaped
        assert_match "claude-swarm", command
        assert_match "--config config.yml", command
        assert_match "--prompt", command
        # Shellwords escaping will handle special characters
        assert_match "Test", command
        assert_match "quotes", command
      end

      test "format_output includes all necessary information" do
        output = Roast::Tools::Swarm.send(:format_output, "test command", "test output", 0)

        assert_match "Command: test command", output
        assert_match "Exit status: 0", output
        assert_match "Output:\ntest output", output
      end

      test "handle_error formats error messages properly" do
        error = Roast::Error.new("Test error")
        result = Roast::Tools::Swarm.send(:handle_error, error)
        assert_equal "Error running swarm: Test error", result
      end

      test "included method registers swarm function" do
        base_class = Class.new do
          class << self
            attr_accessor :registered_functions

            def function(name, description, **params)
              @registered_functions ||= {}
              @registered_functions[name] = { description: description, parameters: params }
            end
          end
        end

        Roast::Tools::Swarm.included(base_class)

        assert base_class.registered_functions.key?(:swarm)
        swarm_func = base_class.registered_functions[:swarm]
        assert_equal "Execute Claude Swarm to orchestrate multiple Claude Code instances", swarm_func[:description]
        assert swarm_func[:parameters][:prompt][:required]
        assert_not swarm_func[:parameters][:path][:required]
      end
    end
  end
end
