# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "ostruct"
require "roast/workflow/api_configuration"
require "roast/workflow/configuration_loader"
require "roast/workflow/resource_resolver"
require "roast/workflow/step_finder"

module Roast
  module Workflow
    # Configuration object for context management settings
    class ContextManagementConfig
      attr_accessor :enabled, :max_tokens, :threshold, :strategy, :character_to_token_ratio, :post_compaction_threshold_buffer, :summarization_model

      def initialize(enabled: false, max_tokens: nil, threshold: 0.75, strategy: "truncation", character_to_token_ratio: 0.25, post_compaction_threshold_buffer: 0.9, summarization_model: nil)
        @enabled = enabled
        @max_tokens = max_tokens
        @threshold = threshold
        @strategy = strategy
        @character_to_token_ratio = character_to_token_ratio
        @post_compaction_threshold_buffer = post_compaction_threshold_buffer
        @summarization_model = summarization_model
      end
    end

    # Encapsulates workflow configuration data and provides structured access
    # to the configuration settings
    class Configuration
      attr_reader :config_hash, :workflow_path, :name, :steps, :tools, :function_configs, :model, :resource
      attr_accessor :target

      delegate :api_provider, :openrouter?, :openai?, to: :api_configuration

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
        @tools = ConfigurationLoader.extract_tools(@config_hash)
        @function_configs = ConfigurationLoader.extract_functions(@config_hash)
        @model = ConfigurationLoader.extract_model(@config_hash)

        # Initialize components
        @api_configuration = ApiConfiguration.new(@config_hash)
        @step_finder = StepFinder.new(@steps)

        # Process target and resource
        @target = ConfigurationLoader.extract_target(@config_hash, options)
        process_resource
      end

      def context_path
        @context_path ||= File.dirname(workflow_path)
      end

      def context_management
        @context_management ||= ContextManagementConfig.new(
          enabled: false,
          max_tokens: nil,
          threshold: 0.75,
          strategy: "truncation",
          character_to_token_ratio: 0.25,
          post_compaction_threshold_buffer: 0.9,
        )
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

      private

      attr_reader :api_configuration

      def process_resource
        if defined?(Roast::Resources)
          @resource = ResourceResolver.resolve(@target, context_path)
          # Update target with processed value for backward compatibility
          @target = @resource.value if has_target?
        end
      end
    end
  end
end
