# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ContextManagerTest < ActiveSupport::TestCase
      def setup
        @config = OpenStruct.new(
          enabled: true,
          strategy: "truncation",
          threshold: 0.75,
          max_tokens: nil,
          character_to_token_ratio: 0.25,
          post_compaction_threshold_buffer: 0.9
        )
        @model = "gpt-4"
        @context_manager = ContextManager.new(config: @config, model: @model)
      end

      test "max_tokens returns model default when config max_tokens is nil" do
        assert_equal 8_192, @context_manager.max_tokens
      end

      test "max_tokens returns config value when provided" do
        @config.max_tokens = 16_000
        assert_equal 16_000, @context_manager.max_tokens
      end

      test "token_threshold calculates correctly" do
        expected = (8_192 * 0.75).to_i
        assert_equal expected, @context_manager.token_threshold
      end

      test "post_compaction_target calculates correctly" do
        threshold = (8_192 * 0.75).to_i
        expected = (threshold * 0.9).to_i
        assert_equal expected, @context_manager.post_compaction_target
      end

      test "count_tokens with character ratio for non-OpenAI models" do
        @context_manager = ContextManager.new(config: @config, model: "claude-3-opus")
        text = "Hello world"
        expected = (text.length * 0.25).ceil
        assert_equal expected, @context_manager.count_tokens(text)
      end

      test "count_tokens returns 0 for nil or empty text" do
        assert_equal 0, @context_manager.count_tokens(nil)
        assert_equal 0, @context_manager.count_tokens("")
      end

      test "count_transcript_tokens sums all message tokens" do
        transcript = [
          { "role" => "system", "content" => "You are a helpful assistant" },
          { "role" => "user", "content" => "Hello" },
          { "role" => "assistant", "content" => "Hi there!" }
        ]
        
        total = @context_manager.count_transcript_tokens(transcript)
        assert total > 0
      end

      test "count_transcript_tokens returns 0 for empty transcript" do
        assert_equal 0, @context_manager.count_transcript_tokens([])
        assert_equal 0, @context_manager.count_transcript_tokens(nil)
      end

      test "needs_compaction? returns false when disabled" do
        @config.enabled = false
        transcript = [{ "role" => "user", "content" => "x" * 10000 }]
        refute @context_manager.needs_compaction?(transcript)
      end

      test "needs_compaction? returns true when transcript exceeds threshold" do
        # Create a large transcript that exceeds threshold
        large_content = "x" * 30000  # Should exceed threshold for most models
        transcript = [{ "role" => "user", "content" => large_content }]
        assert @context_manager.needs_compaction?(transcript)
      end

      test "truncate_transcript preserves system message" do
        system_msg = { "role" => "system", "content" => "You are helpful" }
        user_msg = { "role" => "user", "content" => "Hello" }
        assistant_msg = { "role" => "assistant", "content" => "Hi" }
        
        transcript = [system_msg, user_msg, assistant_msg]
        result = @context_manager.send(:truncate_transcript, transcript)
        
        assert_equal system_msg, result.first
        assert result.any? { |msg| msg["content"]&.include?("[CONTEXT REDUCED:") }
      end

      test "compact_transcript with truncation strategy" do
        @config.strategy = "truncation"
        
        # Create transcript that needs compaction
        large_content = "x" * 30000
        transcript = [
          { "role" => "system", "content" => "System prompt" },
          { "role" => "user", "content" => large_content }
        ]
        
        result = @context_manager.compact_transcript(transcript)
        
        # Should have system message, compaction marker, and potentially preserved messages
        assert result.length >= 2
        assert_equal "system", result.first["role"]
        assert result.any? { |msg| msg["content"]&.include?("[CONTEXT REDUCED:") }
      end

      test "compact_transcript with llm_summarization strategy" do
        @config.strategy = "llm_summarization"
        
        # Create transcript that needs compaction
        large_content = "x" * 30000
        transcript = [
          { "role" => "system", "content" => "System prompt" },
          { "role" => "user", "content" => large_content }
        ]
        
        result = @context_manager.compact_transcript(transcript)
        
        # Should have system message, compaction marker, summary, and potentially preserved messages
        assert result.length >= 2
        assert_equal "system", result.first["role"]
        assert result.any? { |msg| msg["content"]&.include?("[CONTEXT REDUCED:") }
      end
      
      test "uses model-specific character-to-token ratio for Claude models" do
        claude_config = OpenStruct.new(
          enabled: true,
          strategy: "truncation",
          threshold: 0.75,
          character_to_token_ratio: 0.20  # Custom config ratio, but model should override
        )
        
        claude_manager = ContextManager.new(config: claude_config, model: "claude-3-opus-20240229")
        
        # Should use model-specific ratio (0.33) instead of config ratio (0.20)
        text = "Hello world"
        expected_tokens = (text.length * 0.33).ceil
        assert_equal expected_tokens, claude_manager.count_tokens(text)
      end
      
      test "falls back to config ratio when model has no specific ratio" do
        unknown_config = OpenStruct.new(
          enabled: true,
          strategy: "truncation", 
          threshold: 0.75,
          character_to_token_ratio: 0.30
        )
        
        unknown_manager = ContextManager.new(config: unknown_config, model: "unknown-model")
        
        # Should use config ratio (0.30) since model doesn't have a specific one
        text = "Hello world"
        expected_tokens = (text.length * 0.30).ceil
        assert_equal expected_tokens, unknown_manager.count_tokens(text)
      end
      
      test "falls back to default ratio when both model and config have no ratio" do
        minimal_config = OpenStruct.new(
          enabled: true,
          strategy: "truncation",
          threshold: 0.75
        )
        
        minimal_manager = ContextManager.new(config: minimal_config, model: "unknown-model")
        
        # Should use default ratio (0.25)
        text = "Hello world"
        expected_tokens = (text.length * 0.25).ceil
        assert_equal expected_tokens, minimal_manager.count_tokens(text)
      end

      test "compact_transcript returns original when no compaction needed" do
        small_transcript = [
          { "role" => "system", "content" => "System" },
          { "role" => "user", "content" => "Hi" }
        ]
        
        result = @context_manager.compact_transcript(small_transcript)
        assert_equal small_transcript, result
      end

      test "raises error for unknown compaction strategy" do
        @config.strategy = "unknown_strategy"
        
        large_content = "x" * 30000
        transcript = [{ "role" => "user", "content" => large_content }]
        
        assert_raises(ArgumentError) do
          @context_manager.compact_transcript(transcript)
        end
      end

      test "llm_summarization strategy creates summary message" do
        @config.strategy = "llm_summarization"
        
        # Simple mock that returns a summary
        mock_workflow = Minitest::Mock.new
        mock_workflow.expect(:transcript, [])
        mock_workflow.expect(:transcript=, nil, [Array]) 
        mock_workflow.expect(:transcript=, nil, [Array])
        mock_workflow.expect(:with_model, "Test summary", [String])
        
        manager = ContextManager.new(mock_workflow, @config)
        large_transcript = [
          { "role" => "system", "content" => "System prompt" },
          { "role" => "user", "content" => "x" * 10000 }, # Large content
          { "role" => "assistant", "content" => "Recent response" }
        ]
        
        result = manager.compact_transcript(large_transcript)
        
        assert_includes result[1]["content"], "CONTEXT REDUCED"
        assert_equal "assistant", result[2]["role"] # Summary message
        mock_workflow.verify
      end

      test "llm_summarization falls back on failure" do
        @config.strategy = "llm_summarization"
        
        mock_workflow = Minitest::Mock.new
        mock_workflow.expect(:transcript, [])
        mock_workflow.expect(:transcript=, nil, [Array])
        mock_workflow.expect(:transcript=, nil, [Array])
        mock_workflow.expect(:with_model, nil) { raise "LLM failed" }
        
        manager = ContextManager.new(mock_workflow, @config)
        large_transcript = [
          { "role" => "system", "content" => "System" },
          { "role" => "user", "content" => "x" * 5000 }
        ]
        
        result = manager.compact_transcript(large_transcript)
        assert_includes result.last["content"], "Summary:"
        mock_workflow.verify
      end

      test "get_summarization_model selects appropriate models" do
        config = OpenStruct.new(enabled: true, strategy: "llm_summarization")
        
        # Test key model mappings
        manager = ContextManager.new(nil, config)
        
        manager.instance_variable_set(:@model, "gpt-4o")
        assert_equal "gpt-4o-mini", manager.send(:get_summarization_model)
        
        manager.instance_variable_set(:@model, "claude-3.5-sonnet-20241022")
        assert_equal "claude-3-5-haiku-20241022", manager.send(:get_summarization_model)
        
        manager.instance_variable_set(:@model, "gemini-2.0-pro")
        assert_equal "gemini-2.0-flash", manager.send(:get_summarization_model)
      end

      test "get_summarization_model respects override" do
        config = OpenStruct.new(
          enabled: true, 
          strategy: "llm_summarization",
          summarization_model: "custom-model"
        )
        
        manager = ContextManager.new(nil, config)
        manager.instance_variable_set(:@model, "gpt-4o")
        
        assert_equal "custom-model", manager.send(:get_summarization_model)
      end

      test "get_summarization_model handles experimental models" do
        config = OpenStruct.new(enabled: true, strategy: "llm_summarization")
        manager = ContextManager.new(nil, config)
        
        # Experimental models map to stable equivalents
        manager.instance_variable_set(:@model, "gemini-2.0-flash-exp")
        assert_equal "gemini-2.0-flash", manager.send(:get_summarization_model)
        
        manager.instance_variable_set(:@model, "unknown-model")
        assert_equal "gemini-2.0-flash", manager.send(:get_summarization_model)
      end
    end
  end
end