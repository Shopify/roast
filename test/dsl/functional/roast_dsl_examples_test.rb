# frozen_string_literal: true

require "test_helper"

# This test suite validates the incubating example workflows in `dsl/`.
module DSL
  module Functional
    class RoastDSLExamplesTest < FunctionalTest
      test "prototype.rb workflow runs successfully" do
        actual_stdout, actual_stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("dsl/prototype.rb")
        end
        assert_match "Hello World!", actual_stdout
        assert_equal "", actual_stderr
      end

      test "scoped_executors.rb workflow runs successfully" do
        actual_stdout, actual_stderr = in_sandbox :scoped_executors do
          Roast::DSL::Workflow.from_file("dsl/scoped_executors.rb")
        end

        lines = actual_stdout.lines
        assert_equal "--> before\n", lines.shift
        3.times do
          word = lines.shift
          assert_equal word.upcase, lines.shift
        end
        assert_equal "--> after\n", lines.shift
        assert_equal 8, actual_stdout.lines.length
        assert_equal "", actual_stderr
      end

      test "step_communication.rb workflow runs successfully" do
        actual_stdout, actual_stderr = in_sandbox :step_communication do
          Roast::DSL::Workflow.from_file("dsl/step_communication.rb")
        end
        assert_match(/^d([r-][w-][x-]){3}\s+\d+.*\. $/, actual_stdout.lines.first)
        assert_equal "---\n", actual_stdout.lines.second
        assert_match(/^ d([r-][w-][x-]){3}\s+\d+.*\w+$/, actual_stdout.lines.last)
        assert_equal 3, actual_stdout.lines.length
        assert_equal "", actual_stderr
      end
    end
  end
end
