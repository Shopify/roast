# typed: true
# frozen_string_literal: true

require "timeout"

module Roast
  module Workflow
    class InputStep < BaseStep
      attr_reader :prompt_text, :type, :required, :default, :timeout, :options, :step_name

      def initialize(workflow, config:, **kwargs)
        super(workflow, **kwargs)
        parse_config(config)
      end

      def call
        # Get user input based on the configured type
        result = case type
        when "boolean"
          prompt_boolean
        when "choice"
          prompt_choice
        when "password"
          prompt_password
        else
          prompt_text_input
        end

        # Store the result in workflow state if a name was provided
        store_in_state(result) if step_name

        result
      rescue Interrupt
        raise Roast::Errors::ExitEarly
      rescue Timeout::Error
        handle_timeout
      end

      private

      def parse_config(config)
        @prompt_text = config["prompt"] || raise_config_error("Missing 'prompt' in input configuration")
        @step_name = config["name"]
        @type = config["type"] || "text"
        @required = config.fetch("required", false)
        @default = config["default"]
        @timeout = config["timeout"]
        @options = config["options"]

        validate_config
      end

      def validate_config
        if type == "choice" && options.nil?
          raise_config_error("Missing 'options' for choice type input")
        end

        if type == "boolean" && default && ![true, false, "true", "false", "yes", "no"].include?(default)
          raise_config_error("Invalid default value for boolean type: #{default}")
        end
      end

      def prompt_text_input
        loop do
          result = if timeout
            with_timeout { ::CLI::UI.ask(prompt_text, default: default) }
          else
            ::CLI::UI.ask(prompt_text, default: default)
          end

          if required && result.to_s.strip.empty?
            CLI::UI.puts("{{red:This field is required. Please provide a value.}}")
            next
          end

          return result
        end
      end

      def prompt_boolean
        if timeout
          with_timeout { ::CLI::UI.confirm(prompt_text, default: boolean_default) }
        else
          ::CLI::UI.confirm(prompt_text, default: boolean_default)
        end
      end

      def prompt_choice
        if timeout
          with_timeout { ::CLI::UI.ask(prompt_text, options: options, default: default) }
        else
          ::CLI::UI.ask(prompt_text, options: options, default: default)
        end
      end

      def prompt_password
        require "io/console"

        loop do
          result = if timeout
            with_timeout { prompt_password_with_echo_off }
          else
            prompt_password_with_echo_off
          end

          if required && result.to_s.strip.empty?
            CLI::UI.puts("{{red:This field is required. Please provide a value.}}")
            next
          end

          return result
        end
      end

      def prompt_password_with_echo_off
        ::CLI::UI.with_frame_color(:blue) do
          print("🔒 #{prompt_text} ")

          password = if $stdin.tty?
            # Use noecho for TTY environments
            $stdin.noecho { $stdin.gets }.chomp
          else
            # Fall back to regular input for non-TTY environments
            warn("[WARNING] Password will be visible (not running in TTY)")
            $stdin.gets.chomp
          end

          puts # Add newline after password input
          password
        end
      end

      def boolean_default
        case default
        when true, "true", "yes"
          true
        when false, "false", "no"
          false
        end
      end

      def with_timeout(&block)
        Timeout.timeout(timeout, &block)
      end

      def handle_timeout
        CLI::UI.puts("{{yellow:Input timed out after #{timeout} seconds}}")

        if default
          CLI::UI.puts("{{yellow:Using default value: #{default}}}")
          default
        elsif required
          raise_config_error("Required input timed out with no default value")
        end
      end

      def store_in_state(value)
        workflow.output[step_name] = value
      end

      def raise_config_error(message)
        raise WorkflowExecutor::ConfigurationError, message
      end
    end
  end
end
