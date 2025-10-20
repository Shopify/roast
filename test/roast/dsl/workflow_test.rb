# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class WorkflowTest < ActiveSupport::TestCase
      test "from_file raises error when file does not exist" do
        assert_raises(Errno::ENOENT) do
          Workflow.from_file("/non/existent/file.rb")
        end
      end
    end
  end
end
