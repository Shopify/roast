# frozen_string_literal: true

require "yaml"
require "fileutils"

# VCR URL Rewriter for handling proxy URLs in cassettes
#
# This module handles the complexity of recording VCR cassettes with different API endpoints
# (e.g., Shopify internal proxy vs public OpenAI API) while keeping cassettes portable.
#
# ## Usage
#
# **Replay mode (default):**
# ```bash
# bundle exec rake test
# ```
# Uses cassettes as-is with placeholder URLs.
#
# **Recording mode:**
# ```bash
# # With OpenAI API directly
# OPENAI_API_KEY=sk-... RECORD_VCR=true bundle exec rake test
#
# # With Shopify proxy (internal only)
# OPENAI_API_KEY=your-key OPENAI_API_BASE=https://proxy.shopify.ai/v1 RECORD_VCR=true bundle exec rake test
# ```
#
# ## How It Works (Recording Mode)
#
# 1. **Copy existing cassettes to temp directory**
#    - Protects originals from corruption if recording fails
#
# 2. **Transform placeholder → actual URLs in temp cassettes**
#    - Changes `https://api.openai.com/v1` → user's actual URL (from ENV or default)
#    - Allows existing cassettes to match during recording
#
# 3. **Run tests with recording enabled**
#    - New recordings happen in temp directory
#    - Uses actual API endpoint
#
# 4. **Transform actual → placeholder URLs in temp cassettes**
#    - Changes recorded URLs back to `https://api.openai.com/v1`
#    - Scrubs sensitive headers and cookies
#
# 5. **Copy cassettes back to original location**
#    - Only happens if tests complete successfully
#    - Temp directory cleaned up automatically
#
# This ensures cassettes work for:
# - Shopify developers using internal proxy
# - External contributors using public API
# - Anyone re-recording cassettes with their own endpoint
module VCRURLRewriter
  PLACEHOLDER_API_URL = "https://api.openai.com/v1"

  class << self
    attr_reader :temp_cassette_dir, :original_cassette_dir

    # Set up VCR with URL rewriting for recording mode
    def configure!
      return if @configured

      if ENV["RECORD_VCR"]
        setup_recording_mode!
      else
        setup_replay_mode!
      end

      @configured = true
    end

    private

    # Recording mode: Use temp directory with URL transformation
    def setup_recording_mode!
      @original_cassette_dir = "test/fixtures/vcr_cassettes"
      @temp_cassette_dir = Dir.mktmpdir("vcr-cassettes-")

      # Copy existing cassettes to temp and transform URLs
      copy_and_transform_cassettes(
        from: @original_cassette_dir,
        to: @temp_cassette_dir,
        transform: :placeholder_to_actual,
      )

      # Point VCR to temp directory for recording
      VCR.configure do |config|
        config.cassette_library_dir = @temp_cassette_dir

        # After recording: scrub sensitive data
        config.before_record do |interaction|
          scrub_sensitive_headers!(interaction)
        end
      end

      # Register cleanup hook to copy back and transform
      at_exit do
        copy_and_transform_cassettes(
          from: @temp_cassette_dir,
          to: @original_cassette_dir,
          transform: :actual_to_placeholder,
        )
        FileUtils.rm_rf(@temp_cassette_dir)
      end
    end

    # Replay mode: Use normal cassettes with placeholder URLs
    def setup_replay_mode!
      # Nothing special needed - VCR will match placeholder URLs
    end

    # Copy cassettes and optionally transform URLs
    def copy_and_transform_cassettes(from:, to:, transform:)
      return unless Dir.exist?(from)

      FileUtils.mkdir_p(to)

      Dir.glob(File.join(from, "**/*.yml")).each do |cassette_file|
        relative_path = cassette_file.sub("#{from}/", "")
        dest_file = File.join(to, relative_path)
        dest_dir = File.dirname(dest_file)

        FileUtils.mkdir_p(dest_dir) unless Dir.exist?(dest_dir)

        if transform
          transform_cassette_file(cassette_file, dest_file, transform)
        else
          FileUtils.cp(cassette_file, dest_file)
        end
      end
    end

    # Transform URLs in a cassette file
    def transform_cassette_file(source, dest, direction)
      cassette = YAML.load_file(source)

      cassette["http_interactions"]&.each do |interaction|
        request_uri = interaction.dig("request", "uri")
        next unless request_uri

        case direction
        when :placeholder_to_actual
          # Replace placeholder with actual API URL from ENV
          actual_url = actual_api_url
          interaction["request"]["uri"] = request_uri.gsub(PLACEHOLDER_API_URL, actual_url)
        when :actual_to_placeholder
          # Replace any OpenAI URL with placeholder
          if request_uri.include?("/chat/completions")
            uri = URI.parse(request_uri)
            interaction["request"]["uri"] = "#{PLACEHOLDER_API_URL}#{uri.path}"
          end
        end
      end

      File.write(dest, YAML.dump(cassette))
    end

    # Get actual API URL from environment or default
    def actual_api_url
      base = ENV["OPENAI_API_BASE"] || "https://api.openai.com/v1"
      base.chomp("/")
    end

    # Scrub sensitive headers from interactions
    def scrub_sensitive_headers!(interaction)
      request = interaction.request
      response = interaction.response

      # Scrub auth to dummy value
      if request.headers["Authorization"]
        request.headers["Authorization"] = ["Bearer dummy-key"]
      end

      # Remove sensitive response headers
      if response["headers"]
        response["headers"].delete("X-Shopify-Proxy-Provider")
        response["headers"].delete("Openai-Organization")
        response["headers"].delete("Openai-Project")
        response["headers"].delete("Set-Cookie")
        response["headers"].delete("Cf-Ray")
        response["headers"].delete("Cf-Cache-Status")
      end
    end
  end
end
