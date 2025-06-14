# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class StepNameExtractorTest < ActiveSupport::TestCase
      def setup
        @extractor = StepNameExtractor.new
      end

      test "extracts name from string step" do
        assert_equal "my_step", @extractor.extract("my_step", StepTypeResolver::STRING_STEP)
      end

      test "truncates long command steps" do
        long_command = "echo 'this is a very long command that should be truncated'"

        assert_equal "echo 'this is a very...", @extractor.extract(long_command, StepTypeResolver::COMMAND_STEP)
      end

      test "handles short command steps without truncation" do
        assert_equal "pwd", @extractor.extract("pwd", StepTypeResolver::COMMAND_STEP)
      end

      test "extracts labeled hash step name" do
        step = { "analyze_data" => "Analyze the provided data and generate insights" }

        assert_equal "analyze_data", @extractor.extract(step, StepTypeResolver::HASH_STEP)
      end

      test "truncates inline prompt without label" do
        # When the key looks auto-generated from the prompt
        step = { "analyze_this_text_and" => "Analyze this text and list the key requirements" }

        assert_equal "Analyze this text an...", @extractor.extract(step, StepTypeResolver::HASH_STEP)
      end

      test "handles multi-line inline prompts by using first non-empty line" do
        step = {
          "provide_a_detailed_ana" => "\n\n  Provide a detailed analysis of the following:\n  - Item 1\n  - Item 2",
        }

        assert_equal "Provide a detailed a...", @extractor.extract(step, StepTypeResolver::HASH_STEP)
      end

      test "extracts agent step name" do
        step = "^my_agent"
        StepTypeResolver.expects(:extract_name).with(step).returns("my_agent")

        assert_equal "my_agent", @extractor.extract(step, StepTypeResolver::AGENT_STEP)
      end

      test "formats each iteration with item count" do
        step = { "each" => ["item1", "item2", "item3"], "as" => "item", "steps" => ["process"] }

        assert_equal "each (3 items)", @extractor.extract(step, StepTypeResolver::ITERATION_STEP)
      end

      test "formats repeat iteration with times" do
        step = { "repeat" => 5, "steps" => ["do_something"] }

        assert_equal "repeat (5 times)", @extractor.extract(step, StepTypeResolver::ITERATION_STEP)
      end

      test "handles repeat with hash config" do
        step = { "repeat" => { "times" => 3, "until" => "done" }, "steps" => ["check"] }

        assert_equal "repeat (3 times)", @extractor.extract(step, StepTypeResolver::ITERATION_STEP)
      end

      test "shows question mark for unknown repeat count" do
        step = { "repeat" => { "until" => "done" }, "steps" => ["check"] }

        assert_equal "repeat (? times)", @extractor.extract(step, StepTypeResolver::ITERATION_STEP)
      end

      test "extracts if conditional" do
        step = { "if" => "condition", "steps" => ["do_this"] }

        assert_equal "if", @extractor.extract(step, StepTypeResolver::CONDITIONAL_STEP)
      end

      test "extracts unless conditional" do
        step = { "unless" => "condition", "steps" => ["skip_this"] }

        assert_equal "unless", @extractor.extract(step, StepTypeResolver::CONDITIONAL_STEP)
      end

      test "returns fixed names for case and input steps" do
        assert_equal "case", @extractor.extract({}, StepTypeResolver::CASE_STEP)
        assert_equal "input", @extractor.extract({}, StepTypeResolver::INPUT_STEP)
      end
    end
  end
end
