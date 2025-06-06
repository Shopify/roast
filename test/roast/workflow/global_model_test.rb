# frozen_string_literal: true

require "test_helper"

class GlobalModelTest < ActiveSupport::TestCase
  include FixtureHelpers

  def setup
    @workflow_path = File.join(fixtures_dir, "workflow_with_global_model.yml")
    @workflow = mock
    @workflow.stubs(output: {}, final_output: "", output_file: nil)
    @step_class = Roast::Workflow::BaseStep
    @step = mock
    @step.stubs(model: nil)

    # Create a temporary workflow file with global model
    File.write(@workflow_path, {
      "name" => "Workflow with Global Model",
      "model" => "gpt-4o-mini",
      "steps" => ["test_step"],
    }.to_yaml)

    @step_class.stubs(:new).returns(@step)
    @step.stubs(:model=)
    @workflow.stubs(:output)
  end

  def teardown
    File.delete(@workflow_path) if @workflow_path && File.exist?(@workflow_path)
  end

  test "applies global model to steps without specific model" do
    config_hash = YAML.load_file(@workflow_path)
    context_path = File.dirname(@workflow_path)

    step_loader = Roast::Workflow::StepLoader.new(@workflow, config_hash, context_path)

    @step.expects(:model=).with("gpt-4o-mini").once
    step_loader.send(:create_step_instance, @step_class, "test_step", context_path)
  end

  test "step-specific model overrides global model" do
    # Add step-specific configuration
    config_hash = YAML.load_file(@workflow_path).merge({
      "test_step" => {
        "model" => "local-model",
      },
    })

    context_path = File.dirname(@workflow_path)

    step_loader = Roast::Workflow::StepLoader.new(@workflow, config_hash, context_path)

    @step.expects(:model=).with("local-model").once
    step_loader.send(:create_step_instance, @step_class, "test_step", context_path)
  end
end
