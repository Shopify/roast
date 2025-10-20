# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class AgentTokenTrackingIntegrationTest < ActiveSupport::TestCase
      def setup
        @mock_openai_client = mock
        @mock_openai_client.stubs(:chat).returns("choices" => [{ "message" => { "content" => "Regular LLM response" } }])
        OpenAI::Client.stubs(:new).returns(@mock_openai_client)

        @original_openai_key = ENV["OPENAI_API_KEY"]
        ENV["OPENAI_API_KEY"] = "test-key"
      end

      def teardown
        OpenAI::Client.unstub(:new)
        ENV["OPENAI_API_KEY"] = @original_openai_key
      end

      test "workflow tracks agent token usage separately from general usage" do
        workflow = mock
        context_manager = ContextManager.new
        workflow.stubs(:context_manager).returns(context_manager)
        workflow.stubs(:resource).returns(nil)
        workflow.stubs(:output).returns({})
        workflow.stubs(:transcript).returns([])
        workflow.stubs(:append_to_final_output)
        workflow.stubs(:file).returns(nil)
        workflow.stubs(:config).returns({})
        workflow.stubs(:model).returns("gpt-3.5-turbo")

        Thread.current[:workflow_context] = { workflow: workflow }

        messages = [{ role: "user", content: "Hello world" }]
        context_manager.track_usage(messages)

        initial_stats = context_manager.statistics
        assert initial_stats[:total_tokens] > 0
        assert_equal initial_stats[:total_tokens], initial_stats[:general_tokens]
        assert_equal 0, initial_stats[:agent_tokens]

        inline_prompt = "Review this code and identify performance bottlenecks"
        agent_step = AgentStep.new(workflow, name: inline_prompt)

        Roast::Tools::CodingAgent.expects(:run_claude_code)
          .with(inline_prompt, include_context_summary: false, continue: false)
          .returns("Found 3 bottlenecks in the main loop")

        result = agent_step.call

        assert_equal "Found 3 bottlenecks in the main loop", result

        final_stats = context_manager.statistics
        assert final_stats[:total_tokens] > initial_stats[:total_tokens]
        assert final_stats[:agent_tokens] > 0
        assert final_stats[:general_tokens] == initial_stats[:general_tokens]
        assert_equal 1, final_stats[:agent_call_count]
        assert final_stats[:average_tokens_per_agent_call] > 0

        assert_equal final_stats[:total_tokens], final_stats[:general_tokens] + final_stats[:agent_tokens]
      ensure
        Thread.current[:workflow_context] = nil
      end

      test "tracks token usage for failed agent calls" do
        workflow = mock
        context_manager = ContextManager.new
        workflow.stubs(:context_manager).returns(context_manager)

        Thread.current[:workflow_context] = { workflow: workflow }

        prompt = "Test prompt that will fail"

        Roast::Tools::CodingAgent.expects(:run_claude_code).raises(Roast::Tools::CodingAgent::CodingAgentError.new("Simulated failure"))

        initial_stats = context_manager.statistics

        result = Roast::Tools::CodingAgent.call(prompt)

        assert result.start_with?("🤖 Error running CodingAgent:")

        final_stats = context_manager.statistics
        assert final_stats[:agent_tokens] > initial_stats[:agent_tokens]
        assert_equal 1, final_stats[:agent_call_count]
      ensure
        Thread.current[:workflow_context] = nil
      end
    end
  end
end
