# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class JsonReplayTest < ActiveSupport::TestCase
      setup do
        @workflow = BaseWorkflow.new(nil, name: "test_workflow", workflow_configuration: mock_workflow_config)
        @workflow.session_name = "test_session"
        @workflow.storage_type = "file" # Force file storage for this test
        @state_repository = StateRepositoryFactory.create("file")
        @state_manager = StateManager.new(@workflow, state_repository: @state_repository)
      end

      test "JSON response preserved as hash through save/load cycle" do
        # Step 1: Simulate a step that returns JSON
        step1_name = "fetch_data"
        json_result = {
          "name" => "Test",
          "value" => 42,
          "nested" => { "key" => "value" },
          "array" => [1, 2, 3],
        }

        # Save the result to workflow output
        @workflow.output[step1_name] = json_result

        # Save state (must provide a timestamp to make it findable)
        @workflow.session_timestamp = Time.now.strftime("%Y%m%d_%H%M%S_%L")
        @state_manager.save_state(step1_name, json_result)

        # Step 2: Add another step after it
        step2_name = "process_data"
        @workflow.output[step2_name] = "processed"
        @state_manager.save_state(step2_name, "processed")

        # Create a new workflow instance to simulate fresh start for replay
        new_workflow = BaseWorkflow.new(nil, name: "test_workflow", workflow_configuration: mock_workflow_config)
        new_workflow.session_name = "test_session"
        new_workflow.output = {}

        # Load state before step2 (which should restore step1's JSON data)
        replay_handler = ReplayHandler.new(new_workflow, state_repository: @state_repository)
        loaded_state = replay_handler.load_state_and_restore(step2_name, timestamp: @workflow.session_timestamp)

        # Check that the JSON data is still a hash-like object, not a string
        assert loaded_state, "State should have been loaded"
        output_value = new_workflow.output[step1_name]
        assert output_value, "Step 1 output should exist"
        assert output_value.is_a?(Hash) || output_value.is_a?(DotAccessHash), "Output should be a Hash or DotAccessHash, got #{output_value.class}"
        assert_equal "Test", output_value["name"]
        assert_equal 42, output_value["value"]
        assert_equal "value", output_value["nested"]["key"]
        assert_equal [1, 2, 3], output_value["array"]
      end

      test "Complex nested JSON structure preserved through replay" do
        step1_name = "complex_json"
        complex_result = {
          "users" => [
            { "id" => 1, "name" => "Alice", "active" => true },
            { "id" => 2, "name" => "Bob", "active" => false },
          ],
          "metadata" => {
            "total" => 2,
            "page" => 1,
            "filters" => { "status" => "all", "sort" => "name" },
          },
          "timestamp" => "2024-01-01T12:00:00Z",
        }

        @workflow.output[step1_name] = complex_result
        @workflow.session_timestamp = Time.now.strftime("%Y%m%d_%H%M%S_%L")
        @state_manager.save_state(step1_name, complex_result)

        # Add a second step
        step2_name = "analyze_users"
        @workflow.output[step2_name] = "analysis complete"
        @state_manager.save_state(step2_name, "analysis complete")

        # Create new workflow to simulate fresh start
        new_workflow = BaseWorkflow.new(nil, name: "test_workflow", workflow_configuration: mock_workflow_config)
        new_workflow.session_name = "test_session"
        new_workflow.output = {}

        # Replay from step2
        replay_handler = ReplayHandler.new(new_workflow, state_repository: @state_repository)
        loaded_state = replay_handler.load_state_and_restore(step2_name, timestamp: @workflow.session_timestamp)

        # Verify structure is preserved
        assert loaded_state, "State should have been loaded"
        result = new_workflow.output[step1_name]
        assert result, "Step 1 output should exist"
        assert result.is_a?(Hash) || result.is_a?(DotAccessHash), "Output should be a Hash or DotAccessHash"
        assert result["users"].is_a?(Array), "Users should be an array"
        assert_equal true, result["users"][0]["active"]
        assert_equal false, result["users"][1]["active"]
        assert result["metadata"].is_a?(Hash) || result["metadata"].is_a?(DotAccessHash), "Metadata should be a Hash or DotAccessHash"
        assert_equal 2, result["metadata"]["total"]
      end
    end
  end
end
