# frozen_string_literal: true

require "test_helper"

# This test suite validates the example workflows in `examples/`.
module Examples
  module Functional
    EMPTY_PARAMS = Roast::WorkflowParams.new([], [], {})

    class RoastExamplesTest < FunctionalTest
      setup do
        Roast::EventMonitor.reset!
      end

      teardown do
        Roast::EventMonitor.reset!
      end

      test "agent_with_multiple_prompts.rb workflow runs successfully" do
        use_command_runner_fixtures(
          {
            fixture: "agent_transcripts/agent_with_multiple_prompts_0",
            expected_args: [
              "claude",
              "-p",
              "--verbose",
              "--output-format",
              "stream-json",
              "--model",
              "haiku",
            ],
            expected_stdin_content: "What is 2+2?",
          },
          {
            fixture: "agent_transcripts/agent_with_multiple_prompts_1",
            expected_args: [
              "claude",
              "-p",
              "--verbose",
              "--output-format",
              "stream-json",
              "--model",
              "haiku",
              "--resume",
              "51c68f29-7210-4c12-852f-0c169f621488",
            ],
            expected_stdin_content: "Now multiply that by 3",
          },
          {
            fixture: "agent_transcripts/agent_with_multiple_prompts_2",
            expected_args: [
              "claude",
              "-p",
              "--verbose",
              "--output-format",
              "stream-json",
              "--model",
              "haiku",
              "--resume",
              "51c68f29-7210-4c12-852f-0c169f621488",
            ],
            expected_stdin_content: "Now subtract 5",
          },
        )

        stdout, stderr = in_sandbox :simple_agent do
          Roast::Workflow.from_file("examples/agent_with_multiple_prompts.rb", EMPTY_PARAMS)
        end

        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~STDOUT
          [USER PROMPT] What is 2+2?
          The user is asking a simple math question: "What is 2+2?"

          This is a straightforward arithmetic question. The answer is 4.

          This doesn't require any tool usage - it's just a basic math question. I should answer directly and concisely.
          2 + 2 = 4
          [AGENT RESPONSE] 2 + 2 = 4
          [USER PROMPT] Now multiply that by 3
          The user is asking me to multiply the previous answer (4) by 3.

          4 × 3 = 12

          This is another straightforward arithmetic question. No tools needed.
          4 × 3 = 12
          [AGENT RESPONSE] 4 × 3 = 12
          [USER PROMPT] Now subtract 5
          The user is asking me to subtract 5 from the previous answer (12).

          12 - 5 = 7

          This is another straightforward arithmetic question. No tools needed.
          12 - 5 = 7
          [AGENT RESPONSE] 12 - 5 = 7
          [AGENT STATS] Turns: 3
          Duration: 6 seconds
          Cost (USD): $0.0747
          Tokens (claude-haiku-4-5-20251001): 27 in, 198 out
          Session ID: 51c68f29-7210-4c12-852f-0c169f621488
          ((2 + 2) * 3) - 5 = 12
        STDOUT
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "async_cogs.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :async_cogs do
          Roast::Workflow.from_file("examples/async_cogs.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          first
          second
          third
          slow background task 1
          fourth <-- 'slow background task 1'
          fifth
          slow background task 2
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "async_cogs_complex.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :async_cogs_complex do
          Roast::Workflow.from_file("examples/async_cogs_complex.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          first
          third
          fourth
          sixth
          second
          fifth (second said: 'second')
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "call.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :call do
          Roast::Workflow.from_file("examples/call.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        lines = logged_stdout.lines.map(&:strip)
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
        assert_empty logged_stderr
      end

      test "collect_from.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :collect_from do
          Roast::Workflow.from_file("examples/collect_from.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          Could not access :to_upper directly
          Hello --> HELLO --> hello
          World --> WORLD --> world
          Goodnight,Moon --> GOODNIGHT,MOON --> goodnight,moon
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "custom_logging.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :custom_logging do
          Roast::Workflow.from_file("examples/custom_logging.rb", EMPTY_PARAMS)
        end
        assert_empty stderr

        date_pattern = /\(at \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [-+]?\d{4}\)/
        directory_pattern = %r{Directory: /\S+}
        # NOTE: the custom logger in this example logs to STDOUT
        expected_stdout = <<~LOG
          I, 🔥🔥🔥 Workflow Starting (at TIMESTAMP)
          D, Workflow Context:
            Targets: []
            Args: []
            Kwargs: {}
            Temporary Directory: DIRECTORY
            Workflow Directory: examples
            Working Directory: DIRECTORY (at TIMESTAMP)
          I, cmd(:echo) Starting (at TIMESTAMP)
          I, cmd(:echo) ❯ hello world (at TIMESTAMP)
          I, cmd(:echo) Complete (at TIMESTAMP)
          I, 🔥🔥🔥 Workflow Complete (at TIMESTAMP)
        LOG
        cleaned_stdout = stdout.gsub(date_pattern, "(at TIMESTAMP)").gsub(directory_pattern, "Directory: DIRECTORY")
        assert_equal expected_stdout, cleaned_stdout
      end

      test "json_output.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :json_output do
          Roast::Workflow.from_file("examples/json_output.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "outputs.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :outputs do
          Roast::Workflow.from_file("examples/outputs.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          From Outputs: "Upper: HELLO - Original: Hello"
          Explicit Value Access: "HELLO"
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "outputs_bang.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :outputs_bang do
          assert_raises Roast::CogInputManager::CogSkippedError do
            Roast::Workflow.from_file("examples/outputs_bang.rb", EMPTY_PARAMS)
          end
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          Using the `outputs` block should return `nil`: nil
          ❗️ This block is expected to raise an exception ❗️
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "map.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::Workflow.from_file("examples/map.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "map_reduce.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_reduce do
          Roast::Workflow.from_file("examples/map_reduce.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        assert_equal "lower case words: hello world", logged_stdout.strip
        assert_empty logged_stderr
      end

      test "map_with_index.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :map_with_index do
          Roast::Workflow.from_file("examples/map_with_index.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "next_break.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :next_break do
          Roast::Workflow.from_file("examples/next_break.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          [0] middle
          [0] end
          [1] beginning
          Iteration 0: [false, true, true]
          Iteration 1: [true, false, false]
          Iteration 2: did not run at all
          [1] beginning
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "next_break_parallel.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :next_break_parallel do
          Roast::Workflow.from_file("examples/next_break_parallel.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "parallel_map.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :parallel_map do
          Roast::Workflow.from_file("examples/parallel_map.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        # first four lines may appear in a non-deterministic order
        expected_stdout_first_four_lines = [
          "TWO",
          "FOUR",
          "FIVE",
          "SIX",
        ].to_set
        assert_equal expected_stdout_first_four_lines, logged_stdout.lines[...4].map(&:strip).to_set
        # last three lines will always appear in the same order
        expected_stdout_last_three_lines = <<~EOF
          THREE
          ONE
          ONE, TWO, THREE, FOUR, FIVE, SIX
        EOF
        assert_equal expected_stdout_last_three_lines, logged_stdout.lines[4..].join("")
        assert_empty logged_stderr
      end

      test "prototype.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :prototype do
          Roast::Workflow.from_file("examples/prototype.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        lines = logged_stdout.lines.map(&:strip)
        assert_equal "Hello World!", lines.shift
        2.times do
          # match default `date` format
          assert_match(/^\w+ \w+ \d{2} \d{2}:\d{2}:\d{2} \w+ \d{4}$/, lines.shift, "missing date line")
        end
        assert_empty lines
        assert_empty logged_stderr
      end

      test "repeat_loop_results.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :repeat_loop_results do
          Roast::Workflow.from_file("examples/repeat_loop_results.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "ruby_cog.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :ruby_cog do
          Roast::Workflow.from_file("examples/ruby_cog.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          Roast
          Hello, ROAST
          Calling a method: 7
          1 22 333 4444 55555
          Some Number + 1: 8
          Some String to Upper: HELLO, WORLD!
          Multiply 4 * 3: 12
          The long string has 3 lines
          And it has 75 characters
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "shell_sanitization.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :shell_sanitization do
          Roast::Workflow.from_file("examples/shell_sanitization.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        lines = logged_stdout.lines.map(&:strip)
        assert_equal "hello world", lines.shift
        assert_equal "bad", lines.shift
        3.times { assert_equal "hello world ; echo bad", lines.shift }
        assert_empty lines
        assert_empty logged_stderr
      end

      test "step_communication.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :step_communication do
          Roast::Workflow.from_file("examples/step_communication.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        lines = logged_stdout.lines.map(&:strip)
        assert_match(/^d([r-][w-][x-]){3}[@+]?\s+\d+.*\.$/, lines.shift)
        assert_equal "---", lines.shift
        assert_match(/^d([r-][w-][x-]){3}[@+]?\s+\d+.*\w+$/, lines.shift)
        assert_empty lines
        assert_empty logged_stderr
      end

      test "simple_external_cog.rb workflow runs successfully" do
        $LOAD_PATH.unshift(File.expand_path("examples/plugin-gem-example/lib", Dir.pwd))
        stdout, stderr = in_sandbox :simple_external_cog do
          Roast::Workflow.from_file("examples/demo/simple_external_cog.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          I'm a cog!
          I'm a different cog!
          I'm a workflow-specific cog!
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      ensure
        $LOAD_PATH.delete(File.expand_path("examples/plugin-gem-example/lib", Dir.pwd))
      end

      test "multiloading.rb workflow runs successfully" do
        $LOAD_PATH.unshift(File.expand_path("examples/plugin-gem-example/lib", Dir.pwd))
        stdout, stderr = in_sandbox :multiloading do
          Roast::Workflow.from_file("examples/demo/multiloading.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          I'm a cog!
          I'm a different cog!
          I'm a workflow-specific cog!
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      ensure
        $LOAD_PATH.delete(File.expand_path("examples/plugin-gem-example/lib", Dir.pwd))
      end

      test "simple_agent.rb workflow runs successfully" do
        use_command_runner_fixtures(
          {
            fixture: "agent_transcripts/simple_agent",
            expected_args: [
              "claude",
              "-p",
              "--verbose",
              "--output-format",
              "stream-json",
              "--model",
              "haiku",
              "--append-system-prompt",
              "Always respond in haiku form",
            ],
            expected_stdin_content: "What is the world's largest lake?",
          },
        )

        stdout, stderr = in_sandbox :simple_agent do
          Roast::Workflow.from_file("examples/simple_agent.rb", EMPTY_PARAMS)
        end

        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~STDOUT
          [USER PROMPT] What is the world's largest lake?
          The user is asking me a simple geography question about the world's largest lake. This is a straightforward factual question that doesn't require any tools or special context.

          The world's largest lake by surface area is the Caspian Sea, which covers about 143,550 square miles (371,000 square kilometers). It's technically called a "sea" but is actually a lake because it's not connected to the ocean.

          However, I notice the system reminder says "Always respond in haiku form" at the end of the MCP Server Instructions section. Let me check - yes, it says "Always respond in haiku form" in the instructions.

          So I should answer this question in haiku form!

          A haiku has 5-7-5 syllables. Let me craft a haiku about the Caspian Sea being the world's largest lake:

          Caspian spreads wide (5)
          Ancient waters vast and deep (7)
          World's largest lake blue (5)

          Let me double-check the syllables:
          - Cas-pi-an spreads wide = 5 syllables ✓
          - An-cient wa-ters vast and deep = 7 syllables ✓
          - World's lar-gest lake blue = 5 syllables ✓

          Actually wait, let me recount "ancient waters vast and deep":
          An-cient (2) wa-ters (2) vast (1) and (1) deep (1) = 2+2+1+1+1 = 7 ✓

          Perfect!
          Caspian spreads wide—
          Ancient waters vast and deep,
          World's largest lake gleams.
          [AGENT RESPONSE] Caspian spreads wide—
          Ancient waters vast and deep,
          World's largest lake gleams.
          [AGENT STATS] Turns: 1
          Duration: 4 seconds
          Cost (USD): $0.050913
          Tokens (claude-haiku-4-5-20251001): 9 in, 385 out
          Session ID: 6d6782cf-d193-4fc7-b5f4-414bc0cfcd3a
        STDOUT
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "simple_pi_agent.rb workflow runs successfully" do
        use_command_runner_fixtures({
          fixture: "agent_transcripts/simple_pi_agent",
          expected_args: [
            "pi",
            "--mode",
            "json",
            "-p",
            "--model",
            "anthropic/claude-haiku-4-5-20251001",
            "--append-system-prompt",
            "Always respond in haiku form",
            "--no-session",
          ],
          expected_stdin_content: "What is the world's largest lake?",
        })

        stdout, stderr = in_sandbox :simple_pi_agent do
          Roast::Workflow.from_file("examples/simple_pi_agent.rb", EMPTY_PARAMS)
        end

        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        # When show_progress is enabled (the default), text blocks are accumulated and printed
        # as a single unit, and [AGENT RESPONSE] is suppressed to avoid duplication
        expected_stdout = <<~STDOUT
          [USER PROMPT] What is the world's largest lake?
          Caspian spreads wide—
          Ancient waters vast and deep,
          World's largest lake gleams.
          [AGENT RESPONSE] Caspian spreads wide—
          Ancient waters vast and deep,
          World's largest lake gleams.
          [AGENT STATS] Turns: 1
          Duration: 0 seconds
          Cost (USD): $0.024634
          Tokens (claude-haiku-4-5-20251001): 9 in, 25 out
          Session ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
        STDOUT
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "simple_repeat.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :simple_repeat do
          Roast::Workflow.from_file("examples/simple_repeat.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          iteration 0
          iteration 1
          iteration 2
          iteration 3
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "targets_and_params.rb workflow runs successfully" do
        params = Roast::WorkflowParams.new(
          ["one", "two", "three"],
          [:a, :b, :c],
          { hello: "world", goodnight: "moon" },
        )
        stdout, stderr = in_sandbox :targets_and_params do
          Roast::Workflow.from_file("examples/targets_and_params.rb", params)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
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
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end

      test "chat base_url configuration is respected" do
        workflow_code = <<~RUBY
          # typed: false
          # frozen_string_literal: true

          #: self as Roast::Workflow

          config do
            chat(:test) do
              model("gpt-4o")
              api_key("dummy-test-key")
              base_url("http://custom-base-url.example.com/v1")
              assume_model_exists!
            end
          end

          execute do
            chat(:test) { "test message" }
          end
        RUBY

        mock_chat = mock
        mock_chat.stubs(:messages).returns([])
        mock_chat.stubs(:with_temperature).returns(mock_chat)

        mock_response = mock
        mock_response.stubs(:content).returns("test response")
        mock_response.stubs(:model_id).returns("gpt-4o")
        mock_response.stubs(:input_tokens).returns(10)
        mock_response.stubs(:output_tokens).returns(5)

        mock_chat.expects(:ask).with("test message").returns(mock_response)

        mock_context = mock
        mock_context.expects(:chat).with(
          model: "gpt-4o",
          provider: :openai,
          assume_model_exists: true,
        ).returns(mock_chat)

        RubyLLM.expects(:context).yields(mock_context).returns(mock_context)

        mock_context.expects(:openai_api_key=).with("dummy-test-key")
        mock_context.expects(:openai_api_base=).with("http://custom-base-url.example.com/v1")

        _stdout, stderr = in_sandbox :base_url_config_test do
          File.write("examples/base_url_config_test.rb", workflow_code)
          Roast::Workflow.from_file("examples/base_url_config_test.rb", EMPTY_PARAMS)
          File.delete("examples/base_url_config_test.rb")
        end

        assert_empty stderr
      end

      test "temporary_directory.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :temporary_directory do
          Roast::Workflow.from_file("examples/temporary_directory.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        assert_predicate logged_stdout.length, :>, 0
        path = Pathname.new(logged_stdout.strip)
        assert_predicate path, :absolute?
        refute_predicate path, :exist?
        assert_empty logged_stderr
      end

      test "working_directory.rb workflow runs successfully" do
        stdout, stderr = in_sandbox :working_directory do
          Roast::Workflow.from_file("examples/working_directory.rb", EMPTY_PARAMS)
        end
        assert_empty stdout
        assert_empty stderr

        logged_stdout, logged_stderr = original_streams_from_logger_output
        expected_stdout = <<~EOF
          Current working directory: #{Dir.pwd}
          Alternate working directory: /tmp
          Back to original working directory: #{Dir.pwd}
        EOF
        assert_equal expected_stdout, logged_stdout
        assert_empty logged_stderr
      end
    end
  end
end
