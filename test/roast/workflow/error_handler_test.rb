# frozen_string_literal: true

require "test_helper"

class RoastWorkflowErrorHandlerTest < ActiveSupport::TestCase
  def setup
    @workflow = mock("workflow")
    @workflow.stubs(:name).returns("test_workflow")
    @handler = Roast::Workflow::ErrorHandler.new(@workflow)
    @events = []
    @subscription = ActiveSupport::Notifications.subscribe(/roast\./) do |name, _start, _finish, _id, payload|
      @events << { name: name, payload: payload }
    end
    # Reset logger for testing
    Roast::Helpers::Logger.reset
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscription)
  end

  def test_successful_execution_sends_notifications
    step_name = "test_step"
    resource_type = "file"
    result = "success"

    actual_result = @handler.with_error_handling(step_name, resource_type: resource_type) do
      result
    end

    assert_equal(result, actual_result)

    start_event = @events.find { |e| e[:name] == "roast.step.start" }
    assert_not_nil(start_event)
    assert_equal(step_name, start_event[:payload][:step_name])
    assert_equal(resource_type, start_event[:payload][:resource_type])
    assert_equal("test_workflow", start_event[:payload][:workflow_name])

    complete_event = @events.find { |e| e[:name] == "roast.step.complete" }
    assert_not_nil(complete_event)
    assert_equal(step_name, complete_event[:payload][:step_name])
    assert_equal(true, complete_event[:payload][:success])
    assert_kind_of(Float, complete_event[:payload][:execution_time])
    assert_equal(result.length, complete_event[:payload][:result_size])
    assert_equal("test_workflow", complete_event[:payload][:workflow_name])
  end

  def test_workflow_error_sends_error_notification_and_reraises
    step_name = "failing_step"
    error = Roast::Workflow::WorkflowExecutor::StepNotFoundError.new("Step not found", step_name: step_name)

    assert_raises(Roast::Workflow::WorkflowExecutor::StepNotFoundError) do
      @handler.with_error_handling(step_name) do
        raise error
      end
    end

    error_event = @events.find { |e| e[:name] == "roast.step.error" }
    assert_not_nil(error_event)
    assert_equal(step_name, error_event[:payload][:step_name])
    assert_equal("Roast::Workflow::WorkflowExecutor::StepNotFoundError", error_event[:payload][:error])
    assert_equal("Step not found", error_event[:payload][:message])
    assert_kind_of(Float, error_event[:payload][:execution_time])
    assert_equal("test_workflow", error_event[:payload][:workflow_name])
  end

  def test_generic_error_wraps_in_step_execution_error
    step_name = "broken_step"
    original_error = Roast::Error.new("Something went wrong")

    error = assert_raises(Roast::Workflow::WorkflowExecutor::StepExecutionError) do
      @handler.with_error_handling(step_name) do
        raise original_error
      end
    end

    assert_equal("Failed to execute step 'broken_step': Something went wrong", error.message)
    assert_equal(step_name, error.step_name)
    assert_equal(original_error, error.original_error)
  end

  def test_log_error_uses_roast_logger
    message = "Test error message"
    Roast::Helpers::Logger.expects(:error).with(message)

    @handler.log_error(message)
  end

  def test_log_warning_uses_roast_logger
    message = "Test warning message"
    Roast::Helpers::Logger.expects(:warn).with(message)

    @handler.log_warning(message)
  end

  def test_handles_nil_workflow_gracefully
    handler_without_workflow = Roast::Workflow::ErrorHandler.new(nil)
    step_name = "test_step"
    result = "success"

    actual_result = handler_without_workflow.with_error_handling(step_name) do
      result
    end

    assert_equal(result, actual_result)

    complete_event = @events.find { |e| e[:name] == "roast.step.complete" }
    assert_not_nil(complete_event)
    assert_nil(complete_event[:payload][:workflow_name])
  end
end
