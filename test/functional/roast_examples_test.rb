# frozen_string_literal: true

require "test_helper"

# This test suite validates the example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "basic_prompt_workflow" do
    VCR.use_cassette("basic_prompt_workflow") do
      in_sandbox with_workflow: :basic_prompt_workflow, with_sample_data: "skateboard_orders.csv" do
        roast("execute", "basic_prompt_workflow", "-t", "skateboard_orders.csv")
      end
    end
  end

  test "available_tools_demo workflow" do
    VCR.use_cassette("available_tools") do
      in_sandbox with_workflow: :available_tools_demo do
        roast("execute", "available_tools_demo")
      end
    end
  end

  test "grading workflow" do
    VCR.use_cassette("grading") do
      in_sandbox with_workflow: :grading, with_sample_data: "simple_project" do
        roast("execute", "grading", "-t", "simple_project/calculator_test.rb")
      end
    end
  end
end
