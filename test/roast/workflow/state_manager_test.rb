# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StateManagerTest < ActiveSupport::TestCase
      def setup
        @workflow = mock("workflow")
        @workflow.stubs(session_name: "test_session")
        @workflow.stubs(session_timestamp: "20230101_000000_000")
        @workflow.stubs(file: nil)
        @workflow.stubs(output: { "step1" => "result1", "step2" => "result2" })
        @workflow.stubs(transcript: [{ user: "test" }, { assistant: "response" }])
        @workflow.stubs(final_output: ["final result"])
        @workflow.stubs(:metadata).returns({})
        @workflow.stubs(storage_type: nil)

        @logger = mock("logger")
        @state_repository = mock("state_repository")
        StateRepositoryFactory.stubs(:create).returns(@state_repository)

        @state_manager = StateManager.new(@workflow, logger: @logger)
      end

      def test_saves_state_when_session_name_present
        expected_state_data = {
          step_name: "step3",
          order: 2,
          transcript: [{ user: "test" }, { assistant: "response" }],
          output: { "step1" => "result1", "step2" => "result2" },
          metadata: {},
          final_output: ["final result"],
          execution_order: ["step1", "step2"],
        }

        @state_repository.expects(:save_state).with(@workflow, "step3", expected_state_data)

        @state_manager.save_state("step3", "result3")
      end

      def test_does_not_save_state_when_no_session_name
        @workflow.stubs(session_name: nil)

        @state_repository.expects(:save_state).never

        @state_manager.save_state("step1", "result")
      end

      def test_does_not_save_state_when_workflow_does_not_respond_to_session_name
        workflow = mock("workflow_without_session")
        state_manager = StateManager.new(workflow)

        @state_repository.expects(:save_state).never

        state_manager.save_state("step1", "result")
      end

      def test_handles_save_state_errors_gracefully
        error_message = "Failed to save"
        @state_repository.expects(:save_state).raises(Roast::Error.new(error_message))
        @logger.expects(:warn).with("Failed to save workflow state: #{error_message}")

        # Should not raise
        @state_manager.save_state("step1", "result")
      end

      def test_logs_to_stderr_when_no_logger
        state_manager = StateManager.new(@workflow)
        error_message = "Failed to save"
        @state_repository.expects(:save_state).raises(Roast::Error.new(error_message))

        _, err = capture_io do
          state_manager.save_state("step1", "result")
        end

        assert_match(/WARNING: Failed to save workflow state: #{error_message}/, err)
      end

      def test_handles_workflow_without_transcript
        workflow = mock("workflow")
        workflow.stubs(session_name: "test")
        workflow.stubs(session_timestamp: "20230101_000000_000")
        workflow.stubs(file: nil)
        workflow.stubs(output: {})
        workflow.stubs(final_output: [])
        workflow.stubs(metadata: {})
        workflow.stubs(storage_type: nil)
        # Don't stub transcript - workflow doesn't respond to it

        @state_repository.stubs(:save_state)
        state_manager = StateManager.new(workflow)

        expected_state_data = {
          step_name: "step1",
          order: 0,
          transcript: [],
          output: {},
          metadata: {},
          final_output: [],
          execution_order: [],
        }

        @state_repository.expects(:save_state).with(workflow, "step1", expected_state_data)

        state_manager.save_state("step1", "result")
      end

      def test_handles_workflow_without_output
        workflow = mock("workflow")
        workflow.stubs(session_name: "test")
        workflow.stubs(session_timestamp: "20230101_000000_000")
        workflow.stubs(file: nil)
        workflow.stubs(transcript: [])
        workflow.stubs(final_output: [])
        workflow.stubs(metadata: {})
        workflow.stubs(storage_type: nil)
        # Don't stub output - workflow doesn't respond to it

        state_manager = StateManager.new(workflow)

        # When workflow doesn't have output, it should handle gracefully
        # The state manager checks if workflow responds_to?(:output)
        # But it will still try to save state with empty data
        @state_repository.expects(:save_state).with(workflow, "step1", {
          step_name: "step1",
          order: 0,
          transcript: [],
          output: {},
          metadata: {},
          final_output: [],
          execution_order: [],
        })
        state_manager.save_state("step1", "result")
      end

      def test_handles_workflow_without_final_output
        workflow = mock("workflow")
        workflow.stubs(session_name: "test")
        workflow.stubs(session_timestamp: "20230101_000000_000")
        workflow.stubs(file: nil)
        workflow.stubs(output: {})
        workflow.stubs(transcript: [])
        workflow.stubs(metadata: {})
        workflow.stubs(storage_type: nil)
        # Don't stub final_output - workflow doesn't respond to it

        state_manager = StateManager.new(workflow)

        expected_state_data = {
          step_name: "step1",
          order: 0,
          transcript: [],
          output: {},
          metadata: {},
          final_output: [],
          execution_order: [],
        }

        @state_repository.expects(:save_state).with(workflow, "step1", expected_state_data)

        state_manager.save_state("step1", "result")
      end

      def test_should_save_state_returns_true_with_session_name
        assert(@state_manager.should_save_state?)
      end

      def test_should_save_state_returns_false_without_session_name
        @workflow.stubs(session_name: nil)
        refute(@state_manager.should_save_state?)
      end

      def test_should_save_state_returns_false_when_workflow_does_not_respond_to_session_name
        workflow = mock("workflow")
        workflow.stubs(metadata: {})
        state_manager = StateManager.new(workflow)
        refute(state_manager.should_save_state?)
      end

      def test_calculates_correct_step_order_for_existing_step
        @workflow.stubs(output: { "step1" => "r1", "step2" => "r2", "step3" => "r3" })
        @workflow.stubs(file: nil)

        expected_state_data = {
          step_name: "step2",
          order: 1,
          transcript: [{ user: "test" }, { assistant: "response" }],
          output: { "step1" => "r1", "step2" => "r2", "step3" => "r3" },
          metadata: {},
          final_output: ["final result"],
          execution_order: ["step1", "step2", "step3"],
        }

        @state_repository.expects(:save_state).with(@workflow, "step2", expected_state_data)

        @state_manager.save_state("step2", "new_result")
      end

      def test_calculates_correct_step_order_for_new_step
        expected_state_data = {
          step_name: "step3",
          order: 2,
          transcript: [{ user: "test" }, { assistant: "response" }],
          output: { "step1" => "result1", "step2" => "result2" },
          metadata: {},
          final_output: ["final result"],
          execution_order: ["step1", "step2"],
        }

        @state_repository.expects(:save_state).with(@workflow, "step3", expected_state_data)

        @state_manager.save_state("step3", "result3")
      end

      def test_build_state_data_includes_metadata
        # Set up metadata
        metadata = {
          "step1" => { "duration_ms" => 100, "success" => true },
          "step2" => { "duration_ms" => 200, "error" => "timeout" },
        }
        @workflow.stubs(:metadata).returns(metadata)

        state = @state_manager.send(:build_state_data, "test_step", "result")

        assert_equal(metadata, state[:metadata])
      end

      def test_build_state_data_clones_metadata_at_top_level
        original_metadata = { "step1" => { "key" => "value" }, "step2" => { "key2" => "value2" } }
        @workflow.stubs(:metadata).returns(original_metadata)

        state = @state_manager.send(:build_state_data, "test_step", "result")

        # Modify the returned metadata at top level
        state[:metadata]["step3"] = { "new" => "data" }

        # Original should not have step3
        refute(original_metadata.key?("step3"))

        # NOTE: clone is shallow, so nested objects are shared
        # This is the current behavior - changing nested values affects original
        state[:metadata]["step1"]["key"] = "modified"
        assert_equal("modified", original_metadata["step1"]["key"])
      end

      def test_metadata_is_empty_hash_when_workflow_has_no_metadata_method
        # Remove metadata method
        @workflow.unstub(:metadata)

        state = @state_manager.send(:build_state_data, "test_step", "result")

        assert_equal({}, state[:metadata])
      end

      def test_metadata_persists_in_save_state
        # Initial metadata
        metadata = {
          "step1" => {
            "duration_ms" => 150,
            "api_calls" => 3,
            "timestamp" => "2024-01-15T10:30:00Z",
          },
        }
        @workflow.stubs(:metadata).returns(metadata)

        expected_state_data = {
          step_name: "checkpoint",
          order: 2,
          transcript: [{ user: "test" }, { assistant: "response" }],
          output: { "step1" => "result1", "step2" => "result2" },
          final_output: ["final result"],
          execution_order: ["step1", "step2"],
          metadata: metadata,
        }

        @state_repository.expects(:save_state).with(@workflow, "checkpoint", expected_state_data)

        @state_manager.save_state("checkpoint", "result")
      end

      def test_complex_nested_metadata_structures_are_preserved
        complex_metadata = {
          "analysis_step" => {
            "metrics" => {
              "performance" => {
                "cpu_usage" => 45.2,
                "memory_mb" => 512,
              },
              "results" => {
                "found_issues" => 5,
                "severity_levels" => ["high", "medium", "low"],
              },
            },
            "configuration" => {
              "parallel" => true,
              "timeout_seconds" => 300,
            },
          },
          "validation_step" => {
            "passed" => false,
            "errors" => ["Missing required field", "Invalid format"],
          },
        }

        @workflow.stubs(:metadata).returns(complex_metadata)

        state = @state_manager.send(:build_state_data, "save_point", "result")

        # Deep verify the structure
        assert_equal(complex_metadata, state[:metadata])
        assert_equal(45.2, state[:metadata]["analysis_step"]["metrics"]["performance"]["cpu_usage"])
        assert_equal(["high", "medium", "low"], state[:metadata]["analysis_step"]["metrics"]["results"]["severity_levels"])
        assert_equal(false, state[:metadata]["validation_step"]["passed"])
      end
    end
  end
end
