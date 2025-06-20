# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class BaseStepJsonTest < ActiveSupport::TestCase
      setup do
        @workflow = BaseWorkflow.new(nil, name: "test_workflow", workflow_configuration: mock_workflow_config)
        @workflow.output = {}
      end

      test "JSON array response returns parsed array when json is true" do
        step = BaseStep.new(@workflow, name: "test_step")
        step.json = true

        # When json: true, chat_completion returns parsed JSON
        json_response = [{ "id" => 1, "name" => "Item 1" }, { "id" => 2, "name" => "Item 2" }]

        # Stub workflow methods
        @workflow.stub(:openai?, false) do
          @workflow.stub(:chat_completion, json_response) do
            # Stub read_sidecar_prompt to return a simple prompt
            step.stub(:read_sidecar_prompt, "Test prompt") do
              result = step.call

              # Result should be the parsed JSON array
              assert_instance_of Array, result
              assert_equal 1, result[0]["id"]
              assert_equal "Item 1", result[0]["name"]
            end
          end
        end
      end

      test "Non-JSON array response is joined when json is false" do
        step = BaseStep.new(@workflow, name: "test_step")
        step.json = false

        # Raix 1.0 returns a string
        string_response = "Line 1\nLine 2\nLine 3"

        @workflow.stub(:openai?, false) do
          @workflow.stub(:chat_completion, string_response) do
            step.stub(:read_sidecar_prompt, "Test prompt") do
              result = step.call

              # Result should be joined
              assert_instance_of String, result
              assert_equal "Line 1\nLine 2\nLine 3", result
            end
          end
        end
      end

      test "JSON array with nil first element returns array" do
        step = BaseStep.new(@workflow, name: "test_step")
        step.json = true

        # When json: true, chat_completion returns parsed JSON
        json_response = [nil, { "id" => 2, "name" => "Item 2" }, { "id" => 3, "name" => "Item 3" }]

        @workflow.stub(:openai?, false) do
          @workflow.stub(:chat_completion, json_response) do
            step.stub(:read_sidecar_prompt, "Test prompt") do
              result = step.call

              # Should return the parsed array
              assert_instance_of Array, result
              assert_nil result[0]
              assert_equal 2, result[1]["id"]
            end
          end
        end
      end

      test "Nested JSON array response returns parsed array" do
        step = BaseStep.new(@workflow, name: "test_step")
        step.json = true

        # When json: true, chat_completion returns parsed JSON
        json_response = [[{ "id" => 1, "name" => "Nested Item 1" }, { "id" => 2, "name" => "Nested Item 2" }], { "id" => 3, "name" => "Item 3" }]

        @workflow.stub(:openai?, false) do
          @workflow.stub(:chat_completion, json_response) do
            step.stub(:read_sidecar_prompt, "Test prompt") do
              result = step.call

              # Should return the parsed nested array
              assert_instance_of Array, result
              assert_instance_of Array, result[0]
              assert_equal 1, result[0][0]["id"]
              assert_equal "Nested Item 1", result[0][0]["name"]
            end
          end
        end
      end

      test "Hash response is preserved when json is true" do
        step = BaseStep.new(@workflow, name: "test_step")
        step.json = true

        # When json: true, chat_completion returns parsed JSON
        json_response = { "status" => "success", "data" => { "count" => 42 }, "items" => ["a", "b", "c"] }

        @workflow.stub(:openai?, false) do
          @workflow.stub(:chat_completion, json_response) do
            step.stub(:read_sidecar_prompt, "Test prompt") do
              result = step.call

              # Result should be the parsed hash
              assert_instance_of Hash, result
              assert_equal "success", result["status"]
              assert_equal 42, result["data"]["count"]
              assert_equal ["a", "b", "c"], result["items"]
            end
          end
        end
      end
    end
  end
end
