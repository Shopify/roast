# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class Configuration
      VALID_MODELS = {
        openai: [
          "gpt-4-turbo-preview",
          "gpt-4-turbo", 
          "gpt-4",
          "gpt-4-32k",
          "gpt-3.5-turbo",
          "gpt-3.5-turbo-16k"
        ],
        anthropic: [
          "claude-3-opus",
          "claude-3-sonnet",
          "claude-3-haiku",
          "claude-2.1",
          "claude-instant-1.2"
        ],
        local: [
          "llama2",
          "mistral",
          "codellama",
          "vicuna"
        ]
      }.freeze

      DEFAULT_SETTINGS = {
        base_url: "https://api.openai.com/v1",
        model: "claude-opus-4-1",
        temperature: 0.7,
        max_tokens: nil,
        timeout: 300,
        max_retries: 3,
        retry_delay: 1,
        stream_buffer_size: 1024,
        parallel_tools: true,
        tool_timeout: 30
      }.freeze

      attr_accessor :api_key, :base_url, :model, :temperature, :max_tokens,
                    :timeout, :max_retries, :retry_delay, :stream_buffer_size,
                    :parallel_tools, :tool_timeout, :custom_headers

      def initialize
        load_defaults
        load_from_environment
      end

      def valid?
        validate_api_key && validate_base_url && validate_model
      end

      def validate!
        raise ConfigurationError, "API key is required" unless validate_api_key
        raise ConfigurationError, "Invalid base URL: #{@base_url}" unless validate_base_url
        raise ConfigurationError, "Invalid model: #{@model}" unless validate_model
        true
      end

      def to_h
        {
          api_key: masked_api_key,
          base_url: @base_url,
          model: @model,
          temperature: @temperature,
          max_tokens: @max_tokens,
          timeout: @timeout,
          max_retries: @max_retries,
          retry_delay: @retry_delay,
          stream_buffer_size: @stream_buffer_size,
          parallel_tools: @parallel_tools,
          tool_timeout: @tool_timeout,
          custom_headers: @custom_headers
        }
      end

      def load_from_file(path)
        require "yaml"
        
        unless File.exist?(path)
          raise ConfigurationError, "Configuration file not found: #{path}"
        end
        
        config = YAML.load_file(path)
        
        @api_key = config["api_key"] if config["api_key"]
        @base_url = config["base_url"] if config["base_url"]
        @model = config["model"] if config["model"]
        @temperature = config["temperature"] if config["temperature"]
        @max_tokens = config["max_tokens"] if config["max_tokens"]
        @timeout = config["timeout"] if config["timeout"]
        @max_retries = config["max_retries"] if config["max_retries"]
        @retry_delay = config["retry_delay"] if config["retry_delay"]
        @stream_buffer_size = config["stream_buffer_size"] if config["stream_buffer_size"]
        @parallel_tools = config["parallel_tools"] if config.key?("parallel_tools")
        @tool_timeout = config["tool_timeout"] if config["tool_timeout"]
        @custom_headers = config["custom_headers"] if config["custom_headers"]
        
        self
      end

      def save_to_file(path)
        require "yaml"
        
        FileUtils.mkdir_p(File.dirname(path))
        
        config = {
          "base_url" => @base_url,
          "model" => @model,
          "temperature" => @temperature,
          "max_tokens" => @max_tokens,
          "timeout" => @timeout,
          "max_retries" => @max_retries,
          "retry_delay" => @retry_delay,
          "stream_buffer_size" => @stream_buffer_size,
          "parallel_tools" => @parallel_tools,
          "tool_timeout" => @tool_timeout
        }
        
        config["custom_headers"] = @custom_headers if @custom_headers
        
        # Don't save API key to file for security
        config["api_key"] = "# Set via OPENAI_API_KEY environment variable"
        
        File.write(path, YAML.dump(config))
      end

      def provider
        case @base_url
        when /openai\.com/
          :openai
        when /anthropic\.com/
          :anthropic
        when /localhost|127\.0\.0\.1/
          :local
        else
          :custom
        end
      end

      def supports_streaming?
        # Most providers support streaming, but this can be overridden
        true
      end

      def supports_tools?
        # Check if the provider/model supports function calling
        case provider
        when :openai
          @model.start_with?("gpt-")
        when :anthropic
          @model.start_with?("claude-3")
        else
          # Assume custom providers might support tools
          true
        end
      end

      private

      def load_defaults
        DEFAULT_SETTINGS.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
        @custom_headers = {}
      end

      def load_from_environment
        @api_key = ENV["OPENAI_API_KEY"] || ENV["LLM_API_KEY"]
        @base_url = ENV["OPENAI_BASE_URL"] || ENV["LLM_BASE_URL"] || @base_url
        @model = ENV["OPENAI_MODEL"] || ENV["LLM_MODEL"] || @model
        
        # Load numeric settings
        @temperature = ENV["LLM_TEMPERATURE"].to_f if ENV["LLM_TEMPERATURE"]
        @max_tokens = ENV["LLM_MAX_TOKENS"].to_i if ENV["LLM_MAX_TOKENS"]
        @timeout = ENV["LLM_TIMEOUT"].to_i if ENV["LLM_TIMEOUT"]
        @max_retries = ENV["LLM_MAX_RETRIES"].to_i if ENV["LLM_MAX_RETRIES"]
        @retry_delay = ENV["LLM_RETRY_DELAY"].to_i if ENV["LLM_RETRY_DELAY"]
        @tool_timeout = ENV["LLM_TOOL_TIMEOUT"].to_i if ENV["LLM_TOOL_TIMEOUT"]
        
        # Load boolean settings
        @parallel_tools = ENV["LLM_PARALLEL_TOOLS"] != "false" if ENV["LLM_PARALLEL_TOOLS"]
      end

      def validate_api_key
        !@api_key.nil? && !@api_key.empty?
      end

      def validate_base_url
        return false unless @base_url
        
        begin
          uri = URI.parse(@base_url)
          uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        rescue URI::InvalidURIError
          false
        end
      end

      def validate_model
        return true unless @model # Model can be optional
        
        # For known providers, validate against known models
        case provider
        when :openai
          VALID_MODELS[:openai].any? { |m| @model.start_with?(m) }
        when :anthropic
          VALID_MODELS[:anthropic].any? { |m| @model.start_with?(m) }
        else
          # Allow any model for custom providers
          true
        end
      end

      def masked_api_key
        return nil unless @api_key
        
        if @api_key.length > 8
          "#{@api_key[0..3]}...#{@api_key[-4..]}"
        else
          "*" * @api_key.length
        end
      end

      class ConfigurationError < StandardError; end
    end
  end
end