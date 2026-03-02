# frozen_string_literal: true

require "roast/testing/workflow_test"

module Examples
  # Thin wrapper around Roast::Testing::WorkflowTest for internal example tests.
  # New tests should use Roast::Testing::WorkflowTest directly.
  class FunctionalTest < Roast::Testing::WorkflowTest
    self.workflow_dir = File.join(Dir.pwd, "examples")
  end
end
