# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class ExecutorTest < ActiveSupport::TestCase
      test "from_file creates executor and evaluates workflow file" do
        workflow_content = <<~RUBY
          shell "echo 'test workflow'"
        RUBY

        Tempfile.create do |file|
          file.write(workflow_content)
          file.close

          output, _err = capture_io do
            Executor.from_file(file.path)
          end

          assert_match(/test workflow/, output)
        end
      end

      test "workflow can chain multiple shell commands" do
        workflow_content = <<~RUBY
          shell "echo 'First'"
          shell "echo 'Second'"
          shell "echo 'Third'"
        RUBY

        Tempfile.create(["test_workflow", ".rb"]) do |file|
          file.write(workflow_content)
          file.close

          output, _err = capture_io do
            Executor.from_file(file.path)
          end

          lines = output.split("\n")
          assert_equal("First", lines[0])
          assert_equal("Second", lines[1])
          assert_equal("Third", lines[2])
        end
      end

      test "from_file raises error when file does not exist" do
        assert_raises(Errno::ENOENT) do
          Executor.from_file("/non/existent/file.rb")
        end
      end
    end
  end
end
