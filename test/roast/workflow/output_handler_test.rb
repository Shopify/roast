# frozen_string_literal: true

require "test_helper"

class RoastWorkflowOutputHandlerTest < ActiveSupport::TestCase
  def setup
    @handler = Roast::Workflow::OutputHandler.new
    @workflow = mock("workflow")
    @workflow.stubs(:metadata).returns({})
  end

  def test_save_final_output_saves_when_conditions_met
    @workflow.stubs(:session_name).returns("test_session")
    @workflow.stubs(:final_output).returns("Test output")
    @workflow.stubs(:respond_to?).with(:session_name).returns(true)
    @workflow.stubs(:respond_to?).with(:final_output).returns(true)
    @workflow.stubs(:storage_type).returns(nil)

    state_repository = mock("state_repository")
    state_repository.expects(:save_final_output).with(@workflow, "Test output").returns("/path/to/output.txt")
    Roast::Workflow::StateRepositoryFactory.expects(:create).with(nil).returns(state_repository)

    assert_output(nil, "Final output saved to: /path/to/output.txt\n") do
      @handler.save_final_output(@workflow)
    end
  end

  def test_save_final_output_skips_when_no_session_name
    @workflow.stubs(:respond_to?).with(:session_name).returns(false)

    Roast::Workflow::StateRepositoryFactory.expects(:create).never

    @handler.save_final_output(@workflow)
  end

  def test_save_final_output_skips_when_empty_output
    @workflow.stubs(:session_name).returns("test_session")
    @workflow.stubs(:final_output).returns("")
    @workflow.stubs(:respond_to?).with(:session_name).returns(true)
    @workflow.stubs(:respond_to?).with(:final_output).returns(true)

    Roast::Workflow::StateRepositoryFactory.expects(:create).never

    @handler.save_final_output(@workflow)
  end

  def test_save_final_output_handles_errors_gracefully
    @workflow.stubs(:session_name).returns("test_session")
    @workflow.stubs(:final_output).returns("Test output")
    @workflow.stubs(:respond_to?).with(:session_name).returns(true)
    @workflow.stubs(:respond_to?).with(:final_output).returns(true)
    @workflow.stubs(:storage_type).returns(nil)

    state_repository = mock("state_repository")
    state_repository.expects(:save_final_output).raises(Roast::Error, "Save failed")
    Roast::Workflow::StateRepositoryFactory.expects(:create).with(nil).returns(state_repository)

    assert_output(nil, "Warning: Failed to save final output to session: Save failed\n") do
      @handler.save_final_output(@workflow)
    end
  end

  def test_write_results_to_file_when_output_file_specified
    @workflow.stubs(:output_file).returns("/tmp/results.txt")
    @workflow.stubs(:final_output).returns("Test results")

    File.expects(:write).with("/tmp/results.txt", "Test results")

    assert_output("Results saved to /tmp/results.txt\n") do
      @handler.write_results(@workflow)
    end
  end

  def test_write_results_to_stdout_when_no_output_file
    @workflow.stubs(:output_file).returns(nil)
    @workflow.stubs(:final_output).returns("Test results")

    assert_output("Test results\n") do
      @handler.write_results(@workflow)
    end
  end
end
