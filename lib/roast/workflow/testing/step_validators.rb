# frozen_string_literal: true

module Roast
  module Workflow
    module Testing
      # Validators for step inputs and outputs
      module StepValidators
        class << self
          # Validate that a step produces expected output format
          def validate_output_format(result, expected_format)
            case expected_format
            when :string
              result.is_a?(String)
            when :hash
              result.is_a?(Hash)
            when :array
              result.is_a?(Array)
            when :boolean
              [true, false].include?(result)
            when :json
              begin
                JSON.parse(result.to_s) if result.is_a?(String)
                true
              rescue JSON::ParserError
                false
              end
            when Hash
              validate_hash_structure(result, expected_format)
            when Array
              validate_array_structure(result, expected_format)
            else
              raise ArgumentError, "Unknown format type: #{expected_format}"
            end
          end

          # Validate that required fields are present in output
          def validate_required_fields(result, required_fields)
            return false unless result.is_a?(Hash)

            missing_fields = required_fields - result.keys.map(&:to_s)
            if missing_fields.any?
              raise ValidationError, "Missing required fields: #{missing_fields.join(", ")}"
            end

            true
          end

          # Validate output against a schema
          def validate_schema(result, schema)
            SchemaValidator.new(schema).validate(result)
          end

          # Validate that transcript contains expected patterns
          def validate_transcript_pattern(transcript, pattern)
            transcript_text = transcript.map { |entry| entry.values.join(" ") }.join("\n")

            case pattern
            when Regexp
              transcript_text.match?(pattern)
            when String
              transcript_text.include?(pattern)
            when Array
              pattern.all? { |p| validate_transcript_pattern(transcript, p) }
            else
              raise ArgumentError, "Invalid pattern type: #{pattern.class}"
            end
          end

          # Validate tool usage in transcript
          def validate_tool_usage(transcript, expected_tools)
            tool_calls = extract_tool_calls(transcript)

            if expected_tools.is_a?(Array)
              missing_tools = expected_tools - tool_calls.map { |tc| tc[:tool] }
              if missing_tools.any?
                raise ValidationError, "Expected tools not used: #{missing_tools.join(", ")}"
              end
            elsif expected_tools.is_a?(Hash)
              expected_tools.each do |tool, count|
                actual_count = tool_calls.count { |tc| tc[:tool] == tool }
                if actual_count != count
                  raise ValidationError, "Expected #{count} calls to #{tool}, got #{actual_count}"
                end
              end
            end

            true
          end

          private

          def validate_hash_structure(result, expected_structure)
            return false unless result.is_a?(Hash)

            expected_structure.all? do |key, expected_type|
              if result.key?(key.to_s) || result.key?(key.to_sym)
                value = result[key.to_s] || result[key.to_sym]
                validate_value_type(value, expected_type)
              else
                false
              end
            end
          end

          def validate_array_structure(result, expected_structure)
            return false unless result.is_a?(Array)

            if expected_structure.empty?
              true
            elsif expected_structure.size == 1
              # All elements should match the single type
              result.all? { |item| validate_value_type(item, expected_structure.first) }
            else
              false
            end
          end

          def validate_value_type(value, expected_type)
            case expected_type
            when Class
              value.is_a?(expected_type)
            when Symbol
              validate_output_format(value, expected_type)
            when Hash
              validate_hash_structure(value, expected_type)
            when Array
              validate_array_structure(value, expected_type)
            else
              value == expected_type
            end
          end

          def extract_tool_calls(transcript)
            tool_calls = []

            transcript.each do |entry|
              next unless entry[:assistant].is_a?(Hash) && entry[:assistant][:tool_calls]

              entry[:assistant][:tool_calls].each do |tool_call|
                tool_calls << {
                  tool: tool_call[:function][:name],
                  arguments: tool_call[:function][:arguments],
                }
              end
            end

            tool_calls
          end
        end

        # Custom error for validation failures
        class ValidationError < StandardError; end

        # Schema validator for complex validation
        class SchemaValidator
          def initialize(schema)
            @schema = schema
          end

          def validate(data)
            validate_node(data, @schema, "root")
          end

          private

          def validate_node(data, schema, path)
            case schema
            when Hash
              if schema[:type]
                validate_typed_node(data, schema, path)
              else
                validate_object_node(data, schema, path)
              end
            when Array
              validate_array_node(data, schema, path)
            when Class
              unless data.is_a?(schema)
                raise ValidationError, "#{path}: expected #{schema}, got #{data.class}"
              end

              true
            else
              if data != schema
                raise ValidationError, "#{path}: expected #{schema.inspect}, got #{data.inspect}"
              end

              true
            end
          end

          def validate_typed_node(data, schema, path)
            type = schema[:type]

            case type
            when :string
              raise ValidationError, "#{path}: expected string, got #{data.class}" unless data.is_a?(String)
            when :integer
              raise ValidationError, "#{path}: expected integer, got #{data.class}" unless data.is_a?(Integer)
            when :float
              raise ValidationError, "#{path}: expected float, got #{data.class}" unless data.is_a?(Float) || data.is_a?(Integer)
            when :boolean
              raise ValidationError, "#{path}: expected boolean, got #{data.class}" unless [true, false].include?(data)
            when :array
              raise ValidationError, "#{path}: expected array, got #{data.class}" unless data.is_a?(Array)

              if schema[:items]
                data.each_with_index do |item, index|
                  validate_node(item, schema[:items], "#{path}[#{index}]")
                end
              end
            when :object
              raise ValidationError, "#{path}: expected object, got #{data.class}" unless data.is_a?(Hash)

              if schema[:properties]
                validate_object_node(data, schema[:properties], path)
              end
            end

            # Validate additional constraints
            validate_constraints(data, schema, path)

            true
          end

          def validate_object_node(data, schema, path)
            raise ValidationError, "#{path}: expected object, got #{data.class}" unless data.is_a?(Hash)

            schema.each do |key, expected|
              if data.key?(key.to_s) || data.key?(key.to_sym)
                value = data[key.to_s] || data[key.to_sym]
                validate_node(value, expected, "#{path}.#{key}")
              elsif expected.is_a?(Hash) && expected[:required]
                raise ValidationError, "#{path}: missing required field '#{key}'"
              end
            end

            true
          end

          def validate_array_node(data, schema, path)
            raise ValidationError, "#{path}: expected array, got #{data.class}" unless data.is_a?(Array)

            if schema.size == 1
              # Validate all elements against single schema
              data.each_with_index do |item, index|
                validate_node(item, schema.first, "#{path}[#{index}]")
              end
            else
              raise ValidationError, "Complex array schemas not supported"
            end

            true
          end

          def validate_constraints(data, schema, path)
            if schema[:min_length] && data.respond_to?(:length)
              if data.length < schema[:min_length]
                raise ValidationError, "#{path}: length #{data.length} is less than minimum #{schema[:min_length]}"
              end
            end

            if schema[:max_length] && data.respond_to?(:length)
              if data.length > schema[:max_length]
                raise ValidationError, "#{path}: length #{data.length} is greater than maximum #{schema[:max_length]}"
              end
            end

            if schema[:pattern] && data.is_a?(String)
              unless data.match?(schema[:pattern])
                raise ValidationError, "#{path}: does not match pattern #{schema[:pattern]}"
              end
            end

            if schema[:enum]
              unless schema[:enum].include?(data)
                raise ValidationError, "#{path}: value #{data.inspect} not in enum #{schema[:enum].inspect}"
              end
            end
          end
        end
      end
    end
  end
end
