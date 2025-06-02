# frozen_string_literal: true

require "yaml"

module Roast
  module Workflow
    # Handles loading and parsing of workflow configuration files
    class ConfigurationLoader
      class << self
        # Load configuration from a YAML file
        # @param workflow_path [String] Path to the workflow YAML file
        # @return [Hash] The parsed configuration hash
        def load(workflow_path)
          validate_path!(workflow_path)
          config_hash = YAML.load_file(workflow_path)
          validate_config!(config_hash)
          config_hash
        end

        # Extract the workflow name from config or path
        # @param config_hash [Hash] The configuration hash
        # @param workflow_path [String] Path to the workflow file
        # @return [String] The workflow name
        def extract_name(config_hash, workflow_path)
          config_hash["name"] || File.basename(workflow_path, ".yml")
        end

        # Extract steps from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The steps array or empty array
        def extract_steps(config_hash)
          config_hash["steps"] || []
        end

        # Extract pre-processing steps from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The pre_processing array or empty array
        def extract_pre_processing(config_hash)
          config_hash["pre_processing"] || []
        end

        # Extract post-processing steps from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The post_processing array or empty array
        def extract_post_processing(config_hash)
          config_hash["post_processing"] || []
        end

        # Extract tools from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The tools array or empty array
        def extract_local_tools(config_hash)
          config_hash["tools"]&.select { |tool| tool.is_a?(String) } || []
        end

        # Extract MCP tools from the configuration, and convert them to MCP clients
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The MCP tools array or empty array
        def extract_mcp_tools(config_hash)
          tools = config_hash["tools"]&.select { |tool| tool.is_a?(Hash) }
          return [] unless tools&.any?

          tools.map do |tool|
            config = tool.values.first
            client = if config["url"]
              Raix::MCP::SseClient.new(
                config["url"],
                headers: config["env"] || {},
              )
            elsif config["command"]
              args = [config["command"]]
              args += config["args"] if config["args"]
              Raix::MCP::StdioClient.new(*args, config["env"] || {})
            else
              raise ArgumentError, "Invalid MCP tool configuration for #{tool.keys.first}. Provide `url` or `command`."
            end

            Configuration::MCPTool.new(client:, only: config["only"], except: config["except"])
          end
        end

        # Extract function configurations
        # @param config_hash [Hash] The configuration hash
        # @return [Hash] The functions configuration or empty hash
        def extract_functions(config_hash)
          config_hash["functions"] || {}
        end

        # Extract model from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [String, nil] The model name if specified
        def extract_model(config_hash)
          config_hash["model"]
        end

        # Extract target from config or options
        # @param config_hash [Hash] The configuration hash
        # @param options [Hash] Runtime options
        # @return [String, nil] The target if specified
        def extract_target(config_hash, options = {})
          options[:target] || config_hash["target"]
        end

        private

        def validate_path!(workflow_path)
          raise ArgumentError, "Workflow path cannot be nil" if workflow_path.nil?
          raise ArgumentError, "Workflow file not found: #{workflow_path}" unless File.exist?(workflow_path)
          raise ArgumentError, "Workflow path must be a YAML file" unless workflow_path.end_with?(".yml", ".yaml")
        end

        def validate_config!(config_hash)
          raise ArgumentError, "Invalid workflow configuration" unless config_hash.is_a?(Hash)
        end
      end
    end
  end
end
