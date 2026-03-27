# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class ClaudeTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
            @provider = Claude.new(@config)
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

            assert_includes args_received, "--resume"
            resume_index = args_received.index("--resume")
            assert_equal "existing_session", args_received[resume_index + 1]
          end

          test "invoke runs all prompts in order" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Summarize", "Format as JSON"]

            prompts_received = []
            CommandRunner.stubs(:execute).with do |_args, **kwargs|
              prompts_received << kwargs[:stdin_content]
              result_json = { type: "result", subtype: "success", result: "ok" }.to_json
              kwargs[:stdout_handler]&.call(result_json)
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
              if call_count == 1
                result_json = { type: "result", subtype: "success", result: "done", session_id: "session_from_first" }.to_json
              else
                if args.include?("--resume")
                  resume_index = args.index("--resume")
                  sessions_seen << args[resume_index + 1]
                end
                result_json = { type: "result", subtype: "success", result: "finalized" }.to_json
              end
              kwargs[:stdout_handler]&.call(result_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal ["session_from_first"], sessions_seen
          end

          test "invoke stops on first failed invocation" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalizer 1", "Finalizer 2"]

            call_count = 0
            CommandRunner.stubs(:execute).with do |_args, **_kwargs|
              call_count += 1
              true
            end.returns(["", "Error occurred", mock_status(success: false)])

            assert_raises(Claude::ClaudeInvocation::ClaudeFailedError) do
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
              result_json = { type: "result", subtype: "success", result: result_text }.to_json
              kwargs[:stdout_handler]&.call(result_json)
              true
            end.returns(["", "", mock_status(success: true)])

            output = @provider.invoke(input)

            assert_equal "final result", output.response
          end

          test "invoke uses input session when no previous invocation session exists" do
            input = Agent::Input.new
            input.prompts = ["Main task", "Finalize"]
            input.session = "input_session"

            sessions_for_calls = []
            CommandRunner.stubs(:execute).with do |args, **kwargs|
              if args.include?("--resume")
                resume_index = args.index("--resume")
                sessions_for_calls << args[resume_index + 1]
              else
                sessions_for_calls << nil
              end
              result_json = { type: "result", subtype: "success", result: "done" }.to_json
              kwargs[:stdout_handler]&.call(result_json)
              true
            end.returns(["", "", mock_status(success: true)])

            @provider.invoke(input)

            assert_equal ["input_session", "input_session"], sessions_for_calls
          end
        end
      end
    end
  end
end
