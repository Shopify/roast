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

    test "from_file stops the event monitor when a cog raises" do
      with_workflow_file('execute { ruby(:boom) { raise "boom" } }') do |path|
        assert_raises(StandardError) { Workflow.from_file(path, WorkflowParams.new([], [], {})) }

        refute EventMonitor.running?
        refute OutputRouter.enabled?
      end
    end

    test "from_file can run another workflow after one fails" do
      with_workflow_file('execute { ruby(:boom) { raise "boom" } }') do |failing|
        with_workflow_file("execute { ruby(:ok) { 1 } }") do |passing|
          assert_raises(StandardError) { Workflow.from_file(failing, WorkflowParams.new([], [], {})) }

          Workflow.from_file(passing, WorkflowParams.new([], [], {}))
        end
      end
    end

    private

    def with_workflow_file(source)
      Tempfile.create(["workflow", ".rb"]) do |file|
        file.write(source)
        file.flush
        yield file.path
      end
    end
  end
end
