# frozen_string_literal: true

require "test_helper"

# This test suite validates the incubating example workflows in `dsl/`.
module DSL
  module Functional
    class RoastDSLExamplesTest < FunctionalTest
      test "prototype.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("dsl/prototype.rb")
        end
        assert_match "Hello World!", stdout
        assert_empty stderr
      end

      test "scoped_executors.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :scoped_executors do
          Roast::DSL::Workflow.from_file("dsl/scoped_executors.rb")
        end

        lines = stdout.lines.map(&:strip)
        assert_equal "--> before", lines.shift
        3.times do
          word = lines.shift
          assert_equal word.upcase, lines.shift
        end
        assert_equal "---", lines.shift
        assert_match(/^[\w']+$/, lines.shift)
        assert_equal "SCOPE VALUE: ROAST", lines.shift
        assert_match(/^[\w']+$/, lines.shift)
        assert_equal "SCOPE VALUE: OTHER", lines.shift
        assert_equal "--> after", lines.shift
        assert_empty lines
        assert_empty stderr
      end

      test "step_communication.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :step_communication do
          Roast::DSL::Workflow.from_file("dsl/step_communication.rb")
        end
        lines = stdout.lines.map(&:strip)
        assert_match(/^d([r-][w-][x-]){3}\s+\d+.*\.$/, lines.shift)
        assert_equal "---", lines.shift
        assert_match(/^d([r-][w-][x-]){3}\s+\d+.*\w+$/, lines.shift)
        assert_empty lines
        assert_empty stderr
      end
    end
  end
end
