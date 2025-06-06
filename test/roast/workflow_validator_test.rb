# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ValidatorTest < ActiveSupport::TestCase
      # Helper to load fixture content
      def fixture_file_content(filename)
        path = File.join(__dir__, "../fixtures", filename)
        File.read(path)
      end

      def valid_yaml
        @valid_yaml ||= fixture_file_content("valid_workflow.yml")
      end

      def invalid_yaml
        @invalid_yaml ||= fixture_file_content("invalid_workflow.yml")
      end

      test "initializes with valid YAML" do
        assert_nothing_raised do
          Roast::Workflow::Validator.new(valid_yaml)
        end
      end

      test "raises error when YAML is invalid" do
        yaml = "name: - test"
        assert_raises(Psych::SyntaxError) do
          Roast::Workflow::Validator.new(yaml)
        end
      end

      test "valid? returns true for valid YAML that matches schema" do
        validator = Roast::Workflow::Validator.new(valid_yaml)
        assert validator.valid?, "Expected valid? to return true for valid YAML"
      end

      test "valid? returns false for valid YAML that doesn't match schema" do
        validator = Roast::Workflow::Validator.new(invalid_yaml)
        refute validator.valid?, "Expected valid? to return false for invalid YAML"
      end

      test "valid? returns false for empty YAML" do
        yaml = ""
        validator = Roast::Workflow::Validator.new(yaml)
        refute validator.valid?, "Expected valid? to return false for empty YAML"
      end

      test "errors returns empty array when YAML is valid" do
        validator = Roast::Workflow::Validator.new(valid_yaml)
        validator.valid? # Run validation to populate errors
        assert_empty validator.errors, "Expected errors to be empty for valid YAML"
      end

      test "errors returns validation errors when YAML doesn't match schema" do
        validator = Roast::Workflow::Validator.new(invalid_yaml)
        validator.valid? # Run validation to populate errors
        refute_empty validator.errors, "Expected errors to be present for invalid YAML"
        assert_includes validator.errors.first, "steps", "Expected error message to mention 'steps'"
      end
    end
  end
end
