# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles loading and parsing of workflow configuration files
    class ConfigurationLoader
      class ValidationError < Roast::Error; end

      class << self
        # Load configuration from a YAML file
        # @param workflow_path [String] Path to the workflow YAML file
        # @return [Hash] The parsed configuration hash
        def load(workflow_path, options = {})
          validate_path!(workflow_path)

          # Load shared.yml if it exists one level above
          parent_dir = File.dirname(workflow_path)
          shared_path = File.join(parent_dir, "..", "shared.yml")

          yaml_content = ""

          if File.exist?(shared_path)
            yaml_content += File.read(shared_path)
            yaml_content += "\n"
          end

          yaml_content += File.read(workflow_path)

          # Use comprehensive validation if requested
          if options[:comprehensive_validation]
            validator = Validators::ValidationOrchestrator.new(yaml_content, workflow_path)
            unless validator.valid?
              raise_validation_errors(validator)
            end

            # Show warnings if any
            display_warnings(validator.warnings) if validator.warnings.any?
          end

          config_hash = YAML.load(yaml_content, aliases: true)

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

        # Extract tools and tool configurations from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array, Hash] The tools array or empty array
        def extract_tools(config_hash)
          tools_config = config_hash["tools"] || []
          tools = []
          tool_configs = {}

          tools_config.each do |tool_entry|
            case tool_entry
            when String
              tools << tool_entry
            when Hash
              tool_entry.each do |tool_name, config|
                # Skip MCP tool configurations (those with url or command)
                if config.is_a?(Hash) && (config["url"] || config["command"])
                  next
                end

                tools << tool_name
                tool_configs[tool_name] = config || {}
              end
            end
          end

          [tools, tool_configs]
        end

        # Extract MCP tools from the configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Array] The MCP tools array or empty array
        def extract_mcp_tools(config_hash)
          tools = config_hash["tools"]&.select { |tool| tool.is_a?(Hash) } || []
          return [] if tools.none?

          mcp_tools = []
          tools.each do |tool|
            tool.each do |tool_name, config|
              next unless config.is_a?(Hash) && (config["url"] || config["command"])

              mcp_tools << Configuration::MCPTool.new(
                name: tool_name,
                config: config,
                only: config["only"],
                except: config["except"],
              )
            end
          end

          mcp_tools
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

        # Extract context management configuration
        # @param config_hash [Hash] The configuration hash
        # @return [Hash] The context management configuration with defaults
        def extract_context_management(config_hash)
          default_config = {
            enabled: true,
            strategy: "auto",
            threshold: 0.8,
            max_tokens: nil,
            retain_steps: [],
          }

          return default_config unless config_hash["context_management"].is_a?(Hash)

          config = config_hash["context_management"]
          {
            enabled: config.fetch("enabled", default_config[:enabled]),
            strategy: config.fetch("strategy", default_config[:strategy]),
            threshold: config.fetch("threshold", default_config[:threshold]),
            max_tokens: config["max_tokens"],
            retain_steps: config.fetch("retain_steps", default_config[:retain_steps]),
          }
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

        def raise_validation_errors(validator)
          error_messages = validator.errors.map do |error|
            message = "• #{error[:message]}"
            message += " (#{error[:suggestion]})" if error[:suggestion]
            message
          end.join("\n")

          raise ValidationError, <<~ERROR
            Workflow validation failed with #{validator.errors.size} error(s):

            #{error_messages}
          ERROR
        end

        def display_warnings(warnings)
          return if warnings.empty?

          ::CLI::UI::Frame.open("Validation Warnings", color: :yellow) do
            warnings.each do |warning|
              Roast::Log.warn(::CLI::UI.fmt("{{yellow:#{warning[:message]}}}"))
              Roast::Log.warn(::CLI::UI.fmt("  {{gray:→ #{warning[:suggestion]}}}")) if warning[:suggestion]
              puts
            end
          end
        end
      end
    end
  end
end
