# frozen_string_literal: true

module Roast
  module Workflow
    class Validator
      attr_reader :errors

      def initialize(yaml_content)
        @yaml_content = yaml_content&.strip || ""
        @errors = []

        @parsed_yaml = @yaml_content.empty? ? {} : YAML.safe_load(@yaml_content)
      end

      def valid?
        return false if @parsed_yaml.empty?

        schema_path = File.join(Roast::ROOT, "schema/workflow.json")
        schema = JSON.parse(File.read(schema_path))

        begin
          @errors = JSON::Validator.fully_validate(
            schema,
            @parsed_yaml,
            validate_schema: false,
          )

          @errors.empty?
        end
      end
    end
  end
end
