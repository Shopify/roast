# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"

module Roast
  module Workflow
    module Testing
      class StepValidatorsTest < ActiveSupport::TestCase
        test "validates string output format" do
          assert StepValidators.validate_output_format("test", :string)
          refute StepValidators.validate_output_format(123, :string)
          refute StepValidators.validate_output_format({}, :string)
        end

        test "validates hash output format" do
          assert StepValidators.validate_output_format({}, :hash)
          assert StepValidators.validate_output_format({ "key" => "value" }, :hash)
          refute StepValidators.validate_output_format("string", :hash)
          refute StepValidators.validate_output_format([], :hash)
        end

        test "validates array output format" do
          assert StepValidators.validate_output_format([], :array)
          assert StepValidators.validate_output_format([1, 2, 3], :array)
          refute StepValidators.validate_output_format("string", :array)
          refute StepValidators.validate_output_format({}, :array)
        end

        test "validates boolean output format" do
          assert StepValidators.validate_output_format(true, :boolean)
          assert StepValidators.validate_output_format(false, :boolean)
          refute StepValidators.validate_output_format("true", :boolean)
          refute StepValidators.validate_output_format(1, :boolean)
          refute StepValidators.validate_output_format(nil, :boolean)
        end

        test "validates json output format" do
          assert StepValidators.validate_output_format('{"key": "value"}', :json)
          assert StepValidators.validate_output_format("[]", :json)
          refute StepValidators.validate_output_format("invalid json", :json)
          refute StepValidators.validate_output_format("", :json)
        end

        test "validates hash structure" do
          expected = { name: String, age: Integer, active: :boolean }

          assert StepValidators.validate_output_format(
            { "name" => "John", "age" => 30, "active" => true },
            expected,
          )

          refute StepValidators.validate_output_format(
            { "name" => "John", "age" => "30", "active" => true },
            expected,
          )

          refute StepValidators.validate_output_format(
            { "name" => "John", "active" => true },
            expected,
          )
        end

        test "validates array structure" do
          # Array of strings
          assert StepValidators.validate_output_format(
            ["a", "b", "c"],
            [String],
          )

          # Array of hashes
          assert StepValidators.validate_output_format(
            [{ "id" => 1 }, { "id" => 2 }],
            [{ id: Integer }],
          )

          refute StepValidators.validate_output_format(
            ["a", 1, "c"],
            [String],
          )
        end

        test "validates required fields" do
          result = { "name" => "John", "age" => 30 }

          assert StepValidators.validate_required_fields(result, ["name", "age"])

          assert_raises(StepValidators::ValidationError) do
            StepValidators.validate_required_fields(result, ["name", "age", "email"])
          end

          refute StepValidators.validate_required_fields("not a hash", ["field"])
        end

        test "validates transcript pattern with regex" do
          transcript = [
            { user: "Find all users" },
            { assistant: "Searching for users..." },
            { assistant: "Found 5 users" },
          ]

          assert StepValidators.validate_transcript_pattern(transcript, /Found \d+ users/)
          refute StepValidators.validate_transcript_pattern(transcript, /No users found/)
        end

        test "validates transcript pattern with string" do
          transcript = [
            { user: "Hello" },
            { assistant: "Hi there!" },
          ]

          assert StepValidators.validate_transcript_pattern(transcript, "Hi there!")
          refute StepValidators.validate_transcript_pattern(transcript, "Goodbye")
        end

        test "validates transcript pattern with array" do
          transcript = [
            { user: "Start process" },
            { assistant: "Processing..." },
            { assistant: "Complete!" },
          ]

          assert StepValidators.validate_transcript_pattern(
            transcript,
            ["Processing", "Complete"],
          )

          refute StepValidators.validate_transcript_pattern(
            transcript,
            ["Processing", "Failed"],
          )
        end

        test "validates tool usage with array" do
          transcript = [
            { user: "Read file" },
            {
              assistant: {
                tool_calls: [
                  { function: { name: "read_file", arguments: {} } },
                ],
              },
            },
            {
              assistant: {
                tool_calls: [
                  { function: { name: "grep", arguments: {} } },
                ],
              },
            },
          ]

          assert StepValidators.validate_tool_usage(transcript, ["read_file", "grep"])

          assert_raises(StepValidators::ValidationError) do
            StepValidators.validate_tool_usage(transcript, ["read_file", "grep", "write_file"])
          end
        end

        test "validates tool usage with count hash" do
          transcript = [
            {
              assistant: {
                tool_calls: [
                  { function: { name: "read_file", arguments: {} } },
                  { function: { name: "read_file", arguments: {} } },
                ],
              },
            },
            {
              assistant: {
                tool_calls: [
                  { function: { name: "grep", arguments: {} } },
                ],
              },
            },
          ]

          assert StepValidators.validate_tool_usage(
            transcript,
            { "read_file" => 2, "grep" => 1 },
          )

          assert_raises(StepValidators::ValidationError) do
            StepValidators.validate_tool_usage(
              transcript,
              { "read_file" => 1, "grep" => 1 },
            )
          end
        end

        test "schema validator validates simple types" do
          validator = StepValidators::SchemaValidator.new(
            type: :string,
            min_length: 3,
            max_length: 10,
          )

          assert validator.validate("hello")

          assert_raises(StepValidators::ValidationError) do
            validator.validate("hi") # Too short
          end

          assert_raises(StepValidators::ValidationError) do
            validator.validate("hello world!") # Too long
          end
        end

        test "schema validator validates objects" do
          schema = {
            type: :object,
            properties: {
              name: { type: :string, min_length: 1 },
              age: { type: :integer },
              email: { type: :string, pattern: /@/ },
            },
          }

          validator = StepValidators::SchemaValidator.new(schema)

          assert validator.validate({
            "name" => "John",
            "age" => 30,
            "email" => "john@example.com",
          })

          assert_raises(StepValidators::ValidationError) do
            validator.validate({
              "name" => "",
              "age" => 30,
              "email" => "john@example.com",
            })
          end
        end

        test "schema validator validates arrays" do
          schema = {
            type: :array,
            items: { type: :integer },
          }

          validator = StepValidators::SchemaValidator.new(schema)

          assert validator.validate([1, 2, 3])

          assert_raises(StepValidators::ValidationError) do
            validator.validate([1, "2", 3])
          end
        end

        test "schema validator validates enums" do
          schema = {
            type: :string,
            enum: ["red", "green", "blue"],
          }

          validator = StepValidators::SchemaValidator.new(schema)

          assert validator.validate("red")

          assert_raises(StepValidators::ValidationError) do
            validator.validate("yellow")
          end
        end

        test "schema validator validates nested structures" do
          schema = {
            users: [{
              id: { type: :integer },
              profile: {
                name: { type: :string },
                tags: [{ type: :string }],
              },
            }],
          }

          validator = StepValidators::SchemaValidator.new(schema)

          valid_data = {
            "users" => [
              {
                "id" => 1,
                "profile" => {
                  "name" => "John",
                  "tags" => ["admin", "user"],
                },
              },
            ],
          }

          assert validator.validate(valid_data)

          invalid_data = {
            "users" => [
              {
                "id" => "not an integer",
                "profile" => {
                  "name" => "John",
                  "tags" => ["admin", 123], # Invalid: number in tags
                },
              },
            ],
          }

          assert_raises(StepValidators::ValidationError) do
            validator.validate(invalid_data)
          end
        end
      end
    end
  end
end
