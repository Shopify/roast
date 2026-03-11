# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class PiTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.provider(:pi)
            @config.no_display!
            @provider = Pi.new(@config)
          end

          def mock_status(success:)
            status = stub("process_status")
            status.stubs(success?: success)
            status
          end

          test "invoke with single prompt runs a single invocation" do
            input = Agent::Input.new
            input.prompt = "Do something"

            CommandRunner.stubs(:execute).returns(["", "", mock_status(success: true)])

            output = @provider.invoke(input)

            assert_kind_of Agent::Output, output
          end

          test "invoke passes prompt as stdin to the invocation" do
            input = Agent::Input.new
            input.prompt = "Do something"

            stdin_received = nil
            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              stdin_received = kwargs[:stdin_content]
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal "Do something", stdin_received
          end

          test "invoke passes session from input to first invocation" do
            input = Agent::Input.new
            input.prompt = "Do something"
            input.session = "existing_session"

            args_received = nil
            CommandRunner.stubs(:execute).with do |args, **_kwargs|
              args_received = args
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_includes args_received, "--fork"
            fork_index = args_received.index("--fork")
            assert_equal "existing_session", args_received[fork_index + 1]
          end

          test "invoke runs all prompts in order" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Summarize", "Format as JSON"]

            prompts_received = []
            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              prompts_received << kwargs[:stdin_content]
              session_json = { type: "session", id: "session_#{prompts_received.size}" }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal ["Main task", "Summarize", "Format as JSON"], prompts_received
          end

          test "invoke chains session from previous invocation result to next" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalizer"]

            sessions_seen = []
            call_count = 0
            CommandRunner.stubs(:execute).with do |args, **kwargs|
              call_count += 1
              if call_count > 1 && args.include?("--fork")
                fork_index = args.index("--fork")
                sessions_seen << args[fork_index + 1]
              end
              session_id = call_count == 1 ? "session_from_first" : "session_from_second"
              session_json = { type: "session", id: session_id }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal ["session_from_first"], sessions_seen
          end

          test "invoke always uses --fork for session chaining" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalizer"]

            fork_flags = []
            CommandRunner.stubs(:execute).with do |args, **kwargs|
              fork_flags << args.include?("--fork")
              session_json = { type: "session", id: "session_1" }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            # First invocation has no session, so --no-session (no --fork).
            # Second invocation forks from the first session.
            assert_equal [false, true], fork_flags
          end

          test "invoke uses --fork for first invocation when input has session" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalizer"]
            input.session = "external_session"

            fork_flags = []
            CommandRunner.stubs(:execute).with do |args, **kwargs|
              fork_flags << args.include?("--fork")
              session_json = { type: "session", id: "new_session" }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal [true, true], fork_flags
          end

          test "invoke stops on first failed invocation" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalizer 1", "Finalizer 2"]

            call_count = 0
            CommandRunner.stubs(:execute).with do |_args, **_kwargs|
              call_count += 1
              true
            end.returns(["", "Error occurred", mock_status(success: false)])

            assert_raises(Pi::PiInvocation::PiFailedError) do
              @provider.invoke(input)
            end

            assert_equal 1, call_count
          end

          test "invoke returns output from last invocation" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalize it"]

            call_count = 0
            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              call_count += 1
              result_text = call_count == 1 ? "intermediate" : "final result"
              # Pi uses agent_end to extract the final response
              agent_end_json = {
                type: "agent_end",
                messages: [
                  { role: "assistant", content: [{ type: "text", text: result_text }] },
                ],
              }.to_json
              kwargs[:stdout_handler]&.call(agent_end_json)
              # Also emit a session so the chain can continue
              session_json = { type: "session", id: "session_#{call_count}" }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            output = @provider.invoke(input)

            assert_equal "final result", output.response
          end

          test "invoke sums stats across multiple invocations" do
            input = Agent::Input.new
            input.prompts = ["First", "Second"]

            call_count = 0
            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              call_count += 1
              # Simulate turn_start events: 3 turns for first invocation, 5 for second
              num_turns = call_count == 1 ? 3 : 5
              num_turns.times { kwargs[:stdout_handler]&.call({ type: "turn_start" }.to_json) }
              usage_data = {
                type: "message_end",
                message: {
                  role: "assistant",
                  model: "claude-sonnet",
                  content: [{ type: "text", text: call_count == 1 ? "intermediate" : "final" }],
                  usage: {
                    input: call_count == 1 ? 100 : 200,
                    output: call_count == 1 ? 50 : 75,
                    cacheRead: 0,
                    cacheWrite: 0,
                    cost: { total: call_count == 1 ? 0.01 : 0.02 },
                  },
                },
              }.to_json
              kwargs[:stdout_handler]&.call(usage_data)
              session_json = { type: "session", id: "session_#{call_count}" }.to_json
              kwargs[:stdout_handler]&.call(session_json)
              true
            end.returns(["", "", mock_status(success: true)])

            output = @provider.invoke(input)

            assert_equal 8, output.stats.num_turns
            assert_in_delta 0.03, output.stats.usage.cost_usd
            assert_equal 300, output.stats.model_usage["claude-sonnet"].input_tokens
            assert_equal 125, output.stats.model_usage["claude-sonnet"].output_tokens
          end

          test "invoke does not sum stats for single invocation" do
            input = Agent::Input.new
            input.prompt = "Only prompt"

            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              kwargs[:stdout_handler]&.call({ type: "turn_start" }.to_json)
              kwargs[:stdout_handler]&.call({ type: "turn_start" }.to_json)
              kwargs[:stdout_handler]&.call({ type: "turn_start" }.to_json)
              usage_data = {
                type: "message_end",
                message: {
                  role: "assistant",
                  model: "claude-sonnet",
                  content: [{ type: "text", text: "done" }],
                  usage: {
                    input: 100,
                    output: 50,
                    cacheRead: 0,
                    cacheWrite: 0,
                    cost: { total: 0.01 },
                  },
                },
              }.to_json
              kwargs[:stdout_handler]&.call(usage_data)
              true
            end.returns(["", "", mock_status(success: true)])

            output = @provider.invoke(input)

            assert_equal 3, output.stats.num_turns
          end

          test "invoke uses input session when no previous invocation session exists" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalize"]
            input.session = "input_session"

            sessions_for_calls = []
            CommandRunner.stubs(:execute).with do |args, **_kwargs|
              if args.include?("--fork")
                fork_index = args.index("--fork")
                sessions_for_calls << args[fork_index + 1]
              else
                sessions_for_calls << nil
              end
              # Don't emit a session event, so no session chains forward
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            # Both calls should use the input session since no session was returned
            assert_equal ["input_session", "input_session"], sessions_for_calls
          end
        end
      end
    end
  end
end
