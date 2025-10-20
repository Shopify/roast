# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    class ShellScriptStep < BaseStep
      attr_reader :script_path
      attr_accessor :exit_on_error, :env

      def initialize(workflow, script_path:, **options)
        super(workflow, **options)
        @script_path = script_path
        @exit_on_error = true  # default to true
        @env = {}              # custom environment variables
      end

      def call
        validate_script!

        stdout, stderr, status = execute_script

        result = if status.success?
          parse_output(stdout)
        else
          handle_script_error(stderr, status.exitstatus)
        end

        process_output(result, print_response: @print_response)
        result
      end

      private

      def validate_script!
        unless File.exist?(script_path)
          raise Thor::Error, "Shell script not found: #{script_path}"
        end

        unless File.executable?(script_path)
          raise Thor::Error, "Shell script is not executable: #{script_path}. Run: chmod +x #{script_path}"
        end
      end

      def execute_script
        env = setup_environment
        cmd = build_command

        log_debug("Executing shell script: #{cmd}")
        log_debug("Environment: #{env.inspect}")

        Roast::Helpers::CmdRunner.capture3(env, cmd, chdir: Dir.pwd)
      end

      def build_command
        script_path
      end

      def setup_environment
        env_vars = {}

        # Add workflow context as environment variables
        env_vars["ROAST_WORKFLOW_RESOURCE"] = workflow.resource.to_s if workflow.resource
        env_vars["ROAST_STEP_NAME"] = name.value

        # Add workflow outputs as JSON
        if workflow.output && !workflow.output.empty?
          env_vars["ROAST_WORKFLOW_OUTPUT"] = JSON.generate(workflow.output)
        end

        # Add any custom environment variables from step configuration
        if @env.is_a?(Hash)
          @env.each do |key, value|
            env_vars[key.to_s] = value.to_s
          end
        end

        env_vars
      end

      def parse_output(stdout)
        return "" if stdout.strip.empty?

        if @json
          begin
            JSON.parse(stdout.strip)
          rescue JSON::ParserError => e
            raise "Failed to parse shell script output as JSON: #{e.message}\nOutput was: #{stdout.strip}"
          end
        else
          stdout.strip
        end
      end

      def handle_script_error(stderr, exit_code)
        error_message = "Shell script failed with exit code #{exit_code}"
        error_message += "\nError output:\n#{stderr}" unless stderr.strip.empty?

        if @exit_on_error == false
          log_error(error_message)
          # Return stderr as the result when not exiting on error
          stderr.strip.empty? ? "" : stderr.strip
        else
          raise Thor::Error, error_message
        end
      end

      def log_debug(message)
        $stderr.puts "[ShellScriptStep] #{message}" if ENV["ROAST_DEBUG"]
      end

      def log_error(message)
        $stderr.puts "[ShellScriptStep] ERROR: #{message}"
      end
    end
  end
end
