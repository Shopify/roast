# frozen_string_literal: true

require "test_helper"

module Roast
  class WorkflowTest < ActiveSupport::TestCase
    setup do
      Roast::EventMonitor.reset!
    end

    teardown do
      Roast::EventMonitor.reset!
    end

    test "from_file raises error when file does not exist" do
      assert_raises(Errno::ENOENT) do
        Workflow.from_file("/non/existent/file.rb", WorkflowParams.new([], [], {}))
      end
    end
  end
end
