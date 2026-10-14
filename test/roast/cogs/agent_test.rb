# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class AgentTest < ActiveSupport::TestCase
      def setup
        @dir = Dir.mktmpdir
        @record_path = File.join(@dir, "runs", "agent_runs.jsonl")
        @config = Agent::Config.new
        @config.no_display!
        @config.record_agent_runs_to(@record_path)
      end

      def teardown
        FileUtils.remove_entry(@dir)
      end

      def mock_status(success:)
        status = stub("process_status")
        status.stubs(success?: success)
        status
      end

      def stub_claude(response:, session:, stats: {}, stderr: "", success: true)
        CommandRunner.stubs(:execute).with do |_args, **kwargs|
          result = { type: "result", subtype: "success", result: response, session_id: session, **stats }
          kwargs[:stdout_handler]&.call(result.to_json)
          true
        end.returns(["", stderr, mock_status(success:)])
      end

      def records
        File.readlines(@record_path).map { |line| JSON.parse(line) }
      end

      test "does not record runs by default" do
        config = Agent::Config.new
        config.no_display!
        config.provider(:claude)
        stub_claude(response: "done", session: "session_1")

        Dir.chdir(@dir) { run_cog(Agent.new(:planner, ->(_input, _scope, _index) { "Plan it" }), config:) }

        assert_empty Dir.children(@dir)
      end

      test "records a Claude run" do
        @config.provider(:claude)
        @config.model("sonnet")
        @config.append_system_prompt("Be brief")
        stub_claude(
          response: "The plan",
          session: "session_1",
          stats: {
            duration_ms: 1500,
            num_turns: 2,
            total_cost_usd: 0.01,
            modelUsage: { "claude-sonnet" => { inputTokens: 100, outputTokens: 50 } },
          },
        )

        run_cog(Agent.new(:planner, ->(_input, _scope, _index) { ["Plan it", "Summarize"] }), config: @config)

        record = records.sole
        assert_equal(
          {
            "cog" => { "name" => "planner", "path" => [{ "cog" => "agent", "name" => "planner" }] },
            "provider" => "claude",
            "model" => "sonnet",
            "prompts" => ["Plan it", "Summarize"],
            "system_prompt" => { "append" => "Be brief", "replace" => nil },
            "status" => "succeeded",
            "error" => nil,
            "response" => "The plan",
            "session" => "session_1",
            "stats" => {
              "duration_ms" => 3000,
              "num_turns" => 4,
              "usage" => { "input_tokens" => 200, "output_tokens" => 100, "cost_usd" => 0.02 },
              "model_usage" => {
                "claude-sonnet" => { "input_tokens" => 200, "output_tokens" => 100, "cost_usd" => nil },
              },
            },
          },
          record.except("started_at", "finished_at"),
        )
        assert_operator Time.iso8601(record["started_at"]), :<=, Time.iso8601(record["finished_at"])
      end

      test "records a Pi run" do
        @config.provider(:pi)
        @config.replace_system_prompt("You are a reviewer")
        CommandRunner.stubs(:execute).with do |_args, **kwargs|
          message_end = {
            type: "message_end",
            message: {
              role: "assistant",
              model: "claude-sonnet",
              content: [{ type: "text", text: "Looks good" }],
              usage: { input: 100, output: 50, cacheRead: 0, cacheWrite: 0, cost: { total: 0.01 } },
            },
          }
          kwargs[:stdout_handler]&.call({ type: "session", id: "session_1" }.to_json)
          kwargs[:stdout_handler]&.call({ type: "turn_start" }.to_json)
          kwargs[:stdout_handler]&.call(message_end.to_json)
          true
        end.returns(["", "", mock_status(success: true)])

        run_cog(Agent.new(:reviewer, ->(_input, _scope, _index) { "Review it" }), config: @config)

        record = records.sole
        assert_equal "pi", record["provider"]
        assert_nil record["model"]
        assert_equal ["Review it"], record["prompts"]
        assert_equal({ "append" => nil, "replace" => "You are a reviewer" }, record["system_prompt"])
        assert_equal "succeeded", record["status"]
        assert_equal "Looks good", record["response"]
        assert_equal "session_1", record["session"]
        assert_equal 1, record["stats"]["num_turns"]
        assert_equal 100, record["stats"]["model_usage"]["claude-sonnet"]["input_tokens"]
      end

      test "appends one record per run" do
        @config.provider(:claude)
        stub_claude(response: "done", session: "session_1")

        run_cog(Agent.new(:first, ->(_input, _scope, _index) { "One" }), config: @config)
        run_cog(Agent.new(:second, ->(_input, _scope, _index) { "Two" }), config: @config)

        assert_equal ["first", "second"], records.map { |record| record["cog"]["name"] }
      end

      test "records a nil name for an anonymous cog" do
        @config.provider(:claude)
        stub_claude(response: "done", session: "session_1")

        run_cog(Agent.new(Cog.generate_fallback_name, ->(_input, _scope, _index) { "Go" }, anonymous: true), config: @config)

        assert_equal({ "name" => nil, "path" => [{ "cog" => "agent", "name" => nil }] }, records.sole["cog"])
      end

      test "records a failed run and re-raises" do
        @config.provider(:claude)
        stub_claude(response: "", session: "session_1", stderr: "boom", success: false)

        assert_raises(Agent::Providers::Claude::ClaudeInvocation::ClaudeFailedError) do
          run_cog(Agent.new(:planner, ->(_input, _scope, _index) { "Plan it" }), config: @config)
        end

        record = records.sole
        assert_equal "failed", record["status"]
        assert_equal(
          { "class" => "Roast::Cogs::Agent::Providers::Claude::ClaudeInvocation::ClaudeFailedError", "message" => "boom" },
          record["error"],
        )
        assert_equal ["Plan it"], record["prompts"]
        assert_nil record["response"]
        assert_nil record["session"]
        assert_nil record["stats"]
      end

      test "records a timed out run and re-raises" do
        @config.provider(:claude)
        @config.timeout(5)
        CommandRunner.stubs(:execute).raises(CommandRunner::TimeoutError, "Command timed out after 5 seconds")

        assert_raises(CommandRunner::TimeoutError) do
          run_cog(Agent.new(:planner, ->(_input, _scope, _index) { "Plan it" }), config: @config)
        end

        record = records.sole
        assert_equal "timed_out", record["status"]
        assert_equal(
          { "class" => "Roast::CommandRunner::TimeoutError", "message" => "Command timed out after 5 seconds" },
          record["error"],
        )
      end
    end
  end
end
