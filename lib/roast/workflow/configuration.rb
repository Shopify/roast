# frozen_string_literal: true

module Roast
  module Workflow
    # Encapsulates workflow configuration data and provides structured access
    # to the configuration settings
    class Configuration
      MCPTool = Struct.new(:name, :config, :only, :except, keyword_init: true)

      attr_reader :config_hash, :workflow_path, :name, :steps, :pre_processing, :post_processing, :tools, :tool_configs, :mcp_tools, :function_configs, :model, :resource
      attr_accessor :target

      delegate :api_provider, :openrouter?, :openai?, :uri_base, :authentication_failure_reason, to: :api_configuration

      # Delegate api_token to effective_token for backward compatibility
      def api_token
        @api_configuration.effective_token
      end

      def initialize(workflow_path, options = {})
        @workflow_path = workflow_path

        # Load configuration using ConfigurationLoader
        @config_hash = ConfigurationLoader.load(workflow_path)

        # Extract basic configuration values
        @name = ConfigurationLoader.extract_name(@config_hash, workflow_path)
        @steps = ConfigurationLoader.extract_steps(@config_hash)
        @pre_processing = ConfigurationLoader.extract_pre_processing(@config_hash)
        @post_processing = ConfigurationLoader.extract_post_processing(@config_hash)
        @tools, @tool_configs = ConfigurationLoader.extract_tools(@config_hash)
        @mcp_tools = ConfigurationLoader.extract_mcp_tools(@config_hash)
        @function_configs = ConfigurationLoader.extract_functions(@config_hash)
        @model = ConfigurationLoader.extract_model(@config_hash)

        # Initialize components
        @api_configuration = ApiConfiguration.new(@config_hash)
        @step_finder = StepFinder.new(@steps)

        # Process target and resource
        @target = ConfigurationLoader.extract_target(@config_hash, options)
        process_resource

        mark_last_step_for_output
      end

      def context_path
        @context_path ||= File.dirname(workflow_path)
      end

      def basename
        @basename ||= File.basename(workflow_path, ".yml")
      end

      def has_target?
        !target.nil? && !target.empty?
      end

      def get_step_config(step_name)
        @config_hash[step_name] || {}
      end

      # Find the index of a step in the workflow steps array
      # @param [Array] steps Optional - The steps array to search (defaults to self.steps)
      # @param [String] target_step The name of the step to find
      # @return [Integer, nil] The index of the step, or nil if not found
      def find_step_index(steps_array = nil, target_step = nil)
        # Handle different call patterns for backward compatibility
        if steps_array.is_a?(String) && target_step.nil?
          target_step = steps_array
          steps_array = nil
        end

        @step_finder.find_index(target_step, steps_array)
      end

      # Get configuration for a specific function
      # @param function_name [String, Symbol] The name of the function (e.g., 'grep', 'search_file')
      # @return [Hash] The configuration for the function or empty hash if not found
      def function_config(function_name)
        @function_configs[function_name.to_s] || {}
      end

      # Get configuration for a specific tool
      # @param tool_name [String] The name of the tool (e.g., 'Roast::Tools::Cmd')
      # @return [Hash] The configuration for the tool or empty hash if not found
      def tool_config(tool_name)
        @tool_configs[tool_name.to_s] || {}
      end

      private

      attr_reader :api_configuration

      def process_resource
        @resource = ResourceResolver.resolve(@target, context_path)
        # Update target with processed value for backward compatibility
        @target = @resource.value if has_target?
      end

      def mark_last_step_for_output
        return if @steps.empty?

        last_step = find_last_executable_step(@steps.last)
        return unless last_step

        # Get the step name/key
        step_key = extract_step_key(last_step)
        return unless step_key

        # Ensure config exists for this step
        @config_hash[step_key] ||= {}

        # Only set print_response if not already explicitly configured
        @config_hash[step_key]["print_response"] = true unless @config_hash[step_key].key?("print_response")
      end

      def find_last_executable_step(step)
        case step
        when String
          step
        when Hash
          # Check if it's a special step type (if, unless, each, repeat, case)
          if step.key?("if") || step.key?("unless")
            # For conditional steps, try to find the last step in the "then" branch
            then_steps = step["then"] || step["steps"]
            find_last_executable_step(then_steps.last) if then_steps&.any?
          elsif step.key?("each") || step.key?("repeat")
            # For iteration steps, we can't reliably determine the last step
            nil
          elsif step.key?("case")
            # For case steps, we can't reliably determine the last step
            nil
          elsif step.size == 1
            # Regular hash step with variable assignment
            step
          end
        when Array
          # For parallel steps, we can't determine a single "last" step
          nil
        else
          step
        end
      end

      def extract_step_key(step)
        case step
        when String
          step
        when Hash
          step.keys.first
        end
      end
    end
  end
end
