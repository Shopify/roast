# frozen_string_literal: true

require "test_helper"

# This test suite validates the example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "example LLM workflow" do
    in_sandbox with_workflow: :available_tools_demo do
      roast("execute", "available_tools_demo")
    end
  end
end
