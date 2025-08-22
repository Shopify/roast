# frozen_string_literal: true

require "test_helper"

class ExecuteTest < FunctionalTest
  test "error if no workflow configuration provided" do
    error_message = /Workflow configuration file is required/
    assert_output(nil, error_message) do
      roast("execute")
    end
  end

  test "raised error bubbles out in verbose mode" do
    assert_raises(Thor::Error) do
      roast("execute", "-v")
    end
  end

  test "simple workflow with command" do
    in_sandbox(with_workflow: :simple) do
      roast("execute", "simple")
    end
  end
end
