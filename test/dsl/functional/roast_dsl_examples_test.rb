# frozen_string_literal: true

require "test_helper"

# This test suite validates the incubating example workflows in `dsl/`.
module DSL
  module Functional
    class RoastDSLExamplesTest < FunctionalTest
      test "call.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :call do
          Roast::DSL::Workflow.from_file("dsl/call.rb")
        end
        assert_empty stderr
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
      end

      test "collect_from.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :collect_from do
          Roast::DSL::Workflow.from_file("dsl/collect_from.rb")
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          Could not access :to_upper directly
          Hello --> HELLO --> hello
          World --> WORLD --> world
          Goodnight,Moon --> GOODNIGHT,MOON --> goodnight,moon
        EOF
        assert_equal expected_stdout, stdout
      end

      test "outputs.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :outputs do
          Roast::DSL::Workflow.from_file("dsl/outputs.rb")
        end
        assert_empty stderr
        assert_equal "Upper: HELLO", stdout.strip
      end

      test "map.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("dsl/map.rb")
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          HELLO
          WORLD
          GOODNIGHT
          MOON

          HELLO
          WORLD
          GOODNIGHT
          MOON

          MOON
          GOODNIGHT
          WORLD
          HELLO
        EOF
        assert_equal expected_stdout, stdout
      end

      test "map_reduce.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_reduce do
          Roast::DSL::Workflow.from_file("dsl/map_reduce.rb")
        end
        assert_empty stderr
        assert_equal "lower case words: hello world", stdout.strip
      end

      test "map_with_index.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_with_index do
          Roast::DSL::Workflow.from_file("dsl/map_with_index.rb")
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          [0] HELLO
          [1] WORLD
          [2] GOODNIGHT
          [3] MOON
        EOF
        assert_equal expected_stdout, stdout
      end

      test "prototype.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("dsl/prototype.rb")
        end
        assert_empty stderr
        lines = stdout.lines.map(&:strip)
        assert_equal "Hello World!", lines.shift
        2.times do
          # match default `date` format
          assert_match(/^\w+ \w+ \d{2} \d{2}:\d{2}:\d{2} \w+ \d{4}$/, lines.shift, "missing date line")
        end
        assert_empty lines
      end

      test "step_communication.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :step_communication do
          Roast::DSL::Workflow.from_file("dsl/step_communication.rb")
        end
        assert_empty stderr
        lines = stdout.lines.map(&:strip)
        assert_match(/^d([r-][w-][x-]){3}\s+\d+.*\.$/, lines.shift)
        assert_equal "---", lines.shift
        assert_match(/^d([r-][w-][x-]){3}\s+\d+.*\w+$/, lines.shift)
        assert_empty lines
      end

      test "simple_agent.rb workflow runs successfully" do
        # Mock the claude CLI response
        mock_status = mock
        mock_status.expects(:success?).returns(true).at_least_once

        Roast::Helpers::CmdRunner.stubs(:capture3)
          .with("claude", "-p", "Say hi")
          .returns(["Hi! How can I help you today?", "", mock_status])

        stdout, stderr = in_sandbox :simple_agent do
          Roast::DSL::Workflow.from_file("dsl/simple_agent.rb")
        end

        assert_includes stdout, "Hi! How can I help you today?"
        assert_empty stderr
      end
    end
  end
end
