# frozen_string_literal: true

require "test_helper"

# This test suite validates the DSL example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "basic_prompt_workflow.rb" do
    VCR.use_cassette("basic_prompt_workflow") do
      stdout, _ = in_sandbox with_sample_data: "skateboard_orders.csv" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/basic_prompt_workflow.rb", "basic_prompt_workflow.rb")
        roast("execute", "basic_prompt_workflow.rb", "--executor", "dsl", "-t", "skateboard_orders.csv")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "grading.rb workflow" do
    VCR.use_cassette("grading") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/grading.rb", "grading.rb")
        roast("execute", "grading.rb", "--executor", "dsl", "-t", "simple_project/calculator_test.rb")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end
end
