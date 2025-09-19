# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    VERSION = "0.1.0"

    class Error < StandardError; end
    
    class << self
      attr_accessor :config
      
      def configure
        self.config ||= Configuration.new
        yield(config) if block_given?
        config
      end
      
      def reset_config!
        self.config = nil
      end
    end
    
    class Configuration
      attr_accessor :model, :api_key, :base_url, :max_context_tokens,
                    :auto_save_sessions, :session_directory, :theme
      
      def initialize
        @model = ENV["OPENAI_MODEL"] || ENV["LLM_MODEL"] || "claude-opus-4-1"
        @api_key = ENV["OPENAI_API_KEY"] || ENV["ANTHROPIC_API_KEY"] || ENV["LLM_API_KEY"]
        @base_url = ENV["OPENAI_BASE_URL"] || ENV["OPENAI_API_BASE"] || ENV["ANTHROPIC_BASE_URL"] || ENV["LLM_BASE_URL"] || "https://api.openai.com/v1"
        @max_context_tokens = 8000
        @auto_save_sessions = true
        @session_directory = File.expand_path("~/.roast/tui_sessions")
        @theme = :default
        
        # Debug output
        if ENV["DEBUG"]
          puts "[DEBUG] TUI Configuration:"
          puts "  Model: #{@model}"
          puts "  API Key: #{@api_key ? "#{@api_key[0..10]}..." : "NOT SET"}"
          puts "  Base URL: #{@base_url}"
        end
      end
    end
  end
end