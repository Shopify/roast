# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    module Tools
      class Base
        class ValidationError < StandardError; end
        class PermissionDeniedError < StandardError; end

        attr_reader :name, :description, :parameters, :permission_mode

        def initialize(name:, description:, parameters:, permission_mode: :ask)
          @name = name
          @description = description
          @parameters = parameters
          @permission_mode = permission_mode # :ask, :allow, :deny
          @execution_count = 0
          @last_execution_time = nil
        end

        # Execute the tool with given arguments
        def execute(arguments, context = {})
          validate_arguments!(arguments)
          check_permission!(arguments, context)
          
          @execution_count += 1
          @last_execution_time = Time.now
          
          result = perform(arguments, context)
          format_result(result)
        rescue StandardError => e
          handle_error(e)
        end

        # Override in subclasses to implement tool logic
        def perform(arguments, context)
          raise NotImplementedError, "Subclass must implement #perform"
        end

        # Generate OpenAI function schema
        def to_openai_schema
          {
            type: "function",
            function: {
              name: @name,
              description: @description,
              parameters: @parameters
            }
          }
        end

        # Check if this tool can be run in parallel
        def parallel_safe?
          true
        end

        # Get tool statistics
        def stats
          {
            execution_count: @execution_count,
            last_execution_time: @last_execution_time
          }
        end

        protected

        # Validate required and optional arguments
        def validate_arguments!(arguments)
          return unless @parameters["required"]
          
          missing = @parameters["required"] - arguments.keys.map(&:to_s)
          unless missing.empty?
            raise ValidationError, "Missing required parameters for #{@name}: #{missing.join(", ")}"
          end

          # Validate types if specified
          if @parameters["properties"]
            arguments.each do |key, value|
              prop = @parameters["properties"][key.to_s]
              next unless prop
              
              validate_type!(key, value, prop["type"]) if prop["type"]
              validate_enum!(key, value, prop["enum"]) if prop["enum"]
              validate_pattern!(key, value, prop["pattern"]) if prop["pattern"]
            end
          end
        end

        def validate_type!(key, value, expected_type)
          actual_type = case value
                       when String then "string"
                       when Integer then "integer"
                       when Float then "number"
                       when TrueClass, FalseClass then "boolean"
                       when Array then "array"
                       when Hash then "object"
                       when NilClass then "null"
                       else "unknown"
                       end

          return if expected_type == actual_type
          return if expected_type == "number" && actual_type == "integer"
          
          raise ValidationError, "Parameter '#{key}' must be of type #{expected_type}, got #{actual_type}"
        end

        def validate_enum!(key, value, allowed_values)
          unless allowed_values.include?(value)
            raise ValidationError, "Parameter '#{key}' must be one of: #{allowed_values.join(", ")}"
          end
        end

        def validate_pattern!(key, value, pattern)
          unless value.to_s.match?(Regexp.new(pattern))
            raise ValidationError, "Parameter '#{key}' does not match required pattern: #{pattern}"
          end
        end

        # Check permissions based on mode
        def check_permission!(arguments, context)
          case @permission_mode
          when :deny
            raise PermissionDeniedError, "Tool '#{@name}' is disabled"
          when :ask
            if context[:session] && !ask_permission(arguments, context)
              raise PermissionDeniedError, "Permission denied for tool '#{@name}'"
            end
          when :allow
            # No check needed
          end
        end

        def ask_permission(arguments, context)
          return true unless context[:interactive]
          
          CLI::UI::Prompt.confirm(
            "Allow #{@name} with arguments: #{format_arguments_for_prompt(arguments)}?",
            default: true
          )
        end

        def format_arguments_for_prompt(arguments)
          arguments.map { |k, v| "#{k}=#{truncate_value(v)}" }.join(", ")
        end

        def truncate_value(value, max_length = 50)
          str = value.to_s
          return str if str.length <= max_length
          "#{str[0...max_length]}..."
        end

        # Format result for display
        def format_result(result)
          case result
          when String
            result
          when Hash
            result.to_json
          when Array
            result.map(&:to_s).join("\n")
          else
            result.to_s
          end
        end

        # Handle errors appropriately
        def handle_error(error)
          case error
          when ValidationError, PermissionDeniedError
            CLI::UI.puts("{{red:Error: #{error.message}}}", to: :stderr)
            raise error
          else
            CLI::UI.puts("{{red:Unexpected error in #{@name}: #{error.message}}}", to: :stderr)
            CLI::UI.puts("{{red:#{error.backtrace.first(5).join("\n")}}}", to: :stderr) if ENV["DEBUG"]
            raise error
          end
        end

        class << self
          # Factory method to create tool from specification
          def from_spec(spec)
            new(
              name: spec[:name],
              description: spec[:description],
              parameters: spec[:parameters],
              permission_mode: spec[:permission_mode] || :ask
            )
          end

          # Generate parameter schema helpers
          def string_param(description, required: false, enum: nil, pattern: nil, default: nil)
            {
              type: "string",
              description: description,
              enum: enum,
              pattern: pattern,
              default: default
            }.compact
          end

          def integer_param(description, required: false, minimum: nil, maximum: nil, default: nil)
            {
              type: "integer",
              description: description,
              minimum: minimum,
              maximum: maximum,
              default: default
            }.compact
          end

          def boolean_param(description, required: false, default: nil)
            {
              type: "boolean",
              description: description,
              default: default
            }.compact
          end

          def array_param(description, items: nil, required: false, default: nil)
            {
              type: "array",
              description: description,
              items: items,
              default: default
            }.compact
          end

          def object_param(description, properties: nil, required: false)
            {
              type: "object",
              description: description,
              properties: properties
            }.compact
          end
        end
      end
    end
  end
end