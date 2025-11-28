# frozen_string_literal: true

require "test_helper"

# This test suite validates the incubating example workflows in `dsl/`.
module DSL
  module Functional
    EMPTY_PARAMS = Roast::DSL::WorkflowParams.new([], [], {})

    class RoastDSLExamplesTest < FunctionalTest
      test "async_cogs.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :async_cogs do
          Roast::DSL::Workflow.from_file("async_cogs.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          first
          second
          third
          slow background task 1
          fourth <-- 'slow background task 1'
          fifth
          slow background task 2
        EOF
        assert_equal expected_stdout, stdout
      end

      test "async_cogs_complex.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :async_cogs_complex do
          Roast::DSL::Workflow.from_file("async_cogs_complex.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          first
          third
          fourth
          sixth
          second
          fifth (second said: 'second')
        EOF
        assert_equal expected_stdout, stdout
      end

      test "call.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :call do
          Roast::DSL::Workflow.from_file("call.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        lines = stdout.lines.map(&:strip)
        assert_equal "--> before", lines.shift
        3.times do
          word = lines.shift
          assert_equal word.tr("a-z", "A-Z"), lines.shift
        end
        assert_equal "---", lines.shift
        assert_match(/^[\p{L}']+$/, lines.shift)
        assert_equal "SCOPE VALUE: ROAST", lines.shift
        assert_match(/^[\p{L}']+$/, lines.shift)
        assert_equal "SCOPE VALUE: OTHER", lines.shift
        assert_equal "--> after", lines.shift
        assert_empty lines
      end

      test "collect_from.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :collect_from do
          Roast::DSL::Workflow.from_file("collect_from.rb", EMPTY_PARAMS)
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

      test "json_output.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :json_output do
          Roast::DSL::Workflow.from_file("json_output.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          {
            "hello": "world",
            "letters": [
              "aaa",
              "bbb"
            ]
          }

          RAW OUTPUT: {
            "hello": "world",
            "letters": [
              "aaa",
              "bbb"
            ]
          }
          SOME VALUE FROM PARSED OUTPUT: aaa
        EOF
        assert_equal expected_stdout, stdout
      end

      test "outputs.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :outputs do
          Roast::DSL::Workflow.from_file("outputs.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          From Outputs: "Upper: HELLO - Original: Hello"
          Explicit Value Access: "HELLO"
        EOF
        assert_equal expected_stdout, stdout
      end

      test "map.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("map.rb", EMPTY_PARAMS)
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

          goodnight -> GOODNIGHT
        EOF
        assert_equal expected_stdout, stdout
      end

      test "map_reduce.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_reduce do
          Roast::DSL::Workflow.from_file("map_reduce.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        assert_equal "lower case words: hello world", stdout.strip
      end

      test "map_with_index.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_with_index do
          Roast::DSL::Workflow.from_file("map_with_index.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          [0] HELLO
          [1] WORLD
          [2] GOODNIGHT
          [3] MOON

          [0] DEFAULT
          [23] SPECIFIC

          [8] WORLD
          [9] GOODNIGHT
        EOF
        assert_equal expected_stdout, stdout
      end

      test "next_break.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :next_break do
          Roast::DSL::Workflow.from_file("next_break.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          [0] middle
          [0] end
          [1] beginning
          Iteration 0: [false, true, true]
          Iteration 1: [true, false, false]
          Iteration 2: did not run at all
        EOF
        assert_equal expected_stdout, stdout
      end

      test "next_break_parallel.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :next_break_parallel do
          Roast::DSL::Workflow.from_file("next_break_parallel.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          [2] beginning
          [2] middle
          [0] middle
          [0] end
          [1] beginning
          Iteration 0: [false, true, true]
          Iteration 1: [true, false, false]
          Iteration 2: [true, true, false]
        EOF
        assert_equal expected_stdout, stdout
      end

      test "parallel_map.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :parallel_map do
          Roast::DSL::Workflow.from_file("parallel_map.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        # first four lines may appear in a non-deterministic order
        expected_stdout_first_four_lines = [
          "TWO",
          "FOUR",
          "FIVE",
          "SIX",
        ].to_set
        assert_equal expected_stdout_first_four_lines, stdout.lines[...4].map(&:strip).to_set
        # last three lines will always appear in the same order
        expected_stdout_last_three_lines = <<~EOF
          THREE
          ONE
          ONE, TWO, THREE, FOUR, FIVE, SIX
        EOF
        assert_equal expected_stdout_last_three_lines, stdout.lines[4..].join("")
      end

      test "prototype.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::DSL::Workflow.from_file("prototype.rb", EMPTY_PARAMS)
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

      test "repeat_loop_results.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :repeat_loop_results do
          Roast::DSL::Workflow.from_file("repeat_loop_results.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          iteration 0: 7 + 0 -> 7
          iteration 1: 7 + 1 -> 8
          iteration 2: 8 + 2 -> 10
          iteration 3: 10 + 3 -> 13
          Ultimate Loop Result: 13
          ---
          First Iteration Result: 7
          Final Iteration Result: 13
          Second-to-last Iteration Result: 10
          ---
          All :add cog outputs: [7, 8, 10, 13]
          Sum of :add cog output: 38
        EOF
        assert_equal expected_stdout, stdout
      end

      test "ruby_cog.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :ruby_cog do
          Roast::DSL::Workflow.from_file("ruby_cog.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          Roast
          Hello, ROAST
          Calling a method: 7
          1 22 333 4444 55555
        EOF
        assert_equal expected_stdout, stdout
      end

      test "step_communication.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :step_communication do
          Roast::DSL::Workflow.from_file("step_communication.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        lines = stdout.lines.map(&:strip)
        assert_match(/^d([r-][w-][x-]){3}[@+]?\s+\d+.*\.$/, lines.shift)
        assert_equal "---", lines.shift
        assert_match(/^-([r-][w-][x-]){3}[@+]?\s+\d+.*\w+$/, lines.shift)
        assert_empty lines
      end

      test "simple_chat.rb workflow runs successfully" do
        # Skip unless recording VCR or have cassette
        unless ENV["RECORD_VCR"] || File.exist?("test/fixtures/vcr_cassettes/dsl_simple_chat.yml")
          skip "chat functionality requires VCR cassette - run with RECORD_VCR=true to record"
        end

        VCR.use_cassette("dsl_simple_chat") do
          stdout, stderr = in_sandbox :simple_chat do
            Roast::DSL::Workflow.from_file("simple_chat.rb", EMPTY_PARAMS)
          end
          assert_empty stderr
          assert_includes stdout, "deepest lake"
        end
      end

      test "data_analysis_workflow.rb runs successfully" do
        # Skip unless recording VCR or have cassette
        unless ENV["RECORD_VCR"] || File.exist?("test/fixtures/vcr_cassettes/dsl_data_analysis.yml")
          skip "complex chat workflow requires VCR cassette - run with RECORD_VCR=true to record"
        end

        VCR.use_cassette("dsl_data_analysis") do
          stdout, stderr = in_sandbox :data_analysis do
            Roast::DSL::Workflow.from_file("data_analysis_workflow.rb", EMPTY_PARAMS)
          end
          assert_empty stderr
          # Check that multiple chat steps executed
          assert_includes stdout, "Model: gpt-4o-mini"
          assert_includes stdout, "[USER] I have a CSV file with skateboard"
          assert_includes stdout, "[ASSISTANT]"
        end
      end

      test "code_review_workflow.rb runs successfully" do
        # Skip unless recording VCR or have cassette
        unless ENV["RECORD_VCR"] || File.exist?("test/fixtures/vcr_cassettes/dsl_code_review.yml")
          skip "complex agent+chat workflow requires VCR cassette - run with RECORD_VCR=true to record"
        end

        VCR.use_cassette("dsl_code_review") do
          with_agent_mocks do
            stdout, stderr = in_sandbox :code_review do
              Roast::DSL::Workflow.from_file("code_review_workflow.rb", EMPTY_PARAMS)
            end
            assert_empty stderr
            # Check that both agent and chat steps executed
            assert_includes stdout, "[AGENT STATS]" # From agent calls
            assert_includes stdout, "Model: gpt-4o-mini" # From chat calls
            assert_includes stdout, "[USER PROMPT]" # From agent show_prompt
            assert_includes stdout, "[ASSISTANT]" # From chat responses
          end
        end
      end

      test "simple_agent.rb workflow runs successfully" do
        with_agent_mocks do
          stdout, stderr = in_sandbox :simple_agent do
            Roast::DSL::Workflow.from_file("simple_agent.rb", EMPTY_PARAMS)
          end

          # Check that the agent was invoked correctly
          assert_includes stdout, "[USER PROMPT] What is the world's largest lake?"
          assert_includes stdout, "[AGENT STATS]"
          assert_includes stdout, "claude-3-haiku-20240307"
          assert_includes stdout, "15 in, 25 out"
          assert_empty stderr
        end
      end

      test "simple_repeat.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :simple_repeat do
          Roast::DSL::Workflow.from_file("simple_repeat.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          iteration 0
          iteration 1
          iteration 2
          iteration 3
        EOF
        assert_equal expected_stdout, stdout
      end

      test "targets_and_params.rb workflow runs successfully" do
        params = Roast::DSL::WorkflowParams.new(
          ["one", "two", "three"],
          [:a, :b, :c],
          { hello: "world", goodnight: "moon" },
        )
        stdout, stderr = in_sandbox :targets_and_params do
          Roast::DSL::Workflow.from_file("targets_and_params.rb", params)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          workflow targets: ["one", "two", "three"]
          workflow args: [:a, :b, :c]
          workflow kwargs: {hello: "world", goodnight: "moon"}

          All targets = ["one", "two", "three"]
          Argument 'foo' provided? no
          All args = [:a, :b, :c]
          Keyword argument 'name': ''
          Keyword argument 'name' provided: no
        EOF
        assert_equal expected_stdout, stdout
      end

      test "temporary_directory.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :temporary_directory do
          Roast::DSL::Workflow.from_file("temporary_directory.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        assert_predicate stdout.length, :>, 0
        path = Pathname.new(stdout.strip)
        assert_predicate path, :absolute?
        refute_predicate path, :exist?
      end

      test "working_directory.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :working_directory do
          Roast::DSL::Workflow.from_file("working_directory.rb", EMPTY_PARAMS)
        end
        assert_empty stderr
        expected_stdout = <<~EOF
          Current working directory: /fake-testing-dir/dsl
          Alternate working directory: /tmp
          Back to original working directory: /fake-testing-dir/dsl
        EOF
        assert_equal expected_stdout, stdout
      end
    end
  end
end
