# frozen_string_literal: true

require "test_helper"

class VCRURLRewriterTest < ActiveSupport::TestCase
  setup do
    @temp_dir = Dir.mktmpdir("vcr-rewriter-test-")
    @original_configured = VCRURLRewriter.instance_variable_get(:@configured)
    VCRURLRewriter.instance_variable_set(:@configured, false)
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    VCRURLRewriter.instance_variable_set(:@configured, @original_configured)
  end

  test "transform_cassette_file converts placeholder to actual URL" do
    original_env = ENV["OPENAI_API_BASE"]
    ENV["OPENAI_API_BASE"] = "https://my-proxy.example.com/v1"

    source = create_test_cassette("https://api.openai.com/v1/chat/completions")
    dest = File.join(@temp_dir, "output.yml")

    VCRURLRewriter.send(:transform_cassette_file, source, dest, :placeholder_to_actual)

    cassette = YAML.load_file(dest)
    uri = cassette["http_interactions"].first.dig("request", "uri")

    assert_equal "https://my-proxy.example.com/v1/chat/completions", uri
    refute_includes uri, "api.openai.com", "Should replace OpenAI URL with proxy"
  ensure
    ENV["OPENAI_API_BASE"] = original_env
  end

  test "transform_cassette_file converts proxy URL to placeholder" do
    source = create_test_cassette("https://proxy.example.com:443/v1/chat/completions")
    dest = File.join(@temp_dir, "output.yml")

    VCRURLRewriter.send(:transform_cassette_file, source, dest, :actual_to_placeholder)

    cassette = YAML.load_file(dest)
    uri = cassette["http_interactions"].first.dig("request", "uri")

    assert_equal "https://api.openai.com/v1/chat/completions", uri
    refute_includes uri, "proxy.example.com", "Should replace proxy URL"
  end

  test "transform_cassette_file preserves path without duplication" do
    source = create_test_cassette("https://some-proxy.com/v1/chat/completions")
    dest = File.join(@temp_dir, "output.yml")

    VCRURLRewriter.send(:transform_cassette_file, source, dest, :actual_to_placeholder)

    cassette = YAML.load_file(dest)
    uri = cassette["http_interactions"].first.dig("request", "uri")

    refute_includes uri, "/v1/v1", "Should not duplicate path segments"
    assert_includes uri, "/v1/chat/completions", "Should preserve single /v1 path"
  end

  test "scrub_interaction_data replaces auth with dummy value" do
    interaction = {
      "request" => {
        "headers" => {
          "Authorization" => ["Bearer sk-real-key-12345"],
        },
      },
      "response" => { "headers" => {} },
    }

    VCRURLRewriter.send(:scrub_interaction_data!, interaction)

    assert_equal ["Bearer dummy-key"], interaction.dig("request", "headers", "Authorization")
  end

  test "scrub_interaction_data keeps only safe response headers" do
    interaction = {
      "request" => { "headers" => {} },
      "response" => {
        "headers" => {
          "Content-Type" => ["application/json"],
          "Date" => ["Mon, 01 Jan 2024 00:00:00 GMT"],
          "Content-Length" => ["123"],
          "Set-Cookie" => ["session=abc123"],
          "X-Shopify-Custom" => ["internal"],
          "Openai-Organization" => ["org-123"],
        },
      },
    }

    VCRURLRewriter.send(:scrub_interaction_data!, interaction)

    headers = interaction.dig("response", "headers")
    assert_includes headers, "Content-Type"
    assert_includes headers, "Date"
    assert_includes headers, "Content-Length"

    refute_includes headers, "Set-Cookie"
    refute_includes headers, "X-Shopify-Custom"
    refute_includes headers, "Openai-Organization"
  end

  test "actual_api_url returns ENV value when set" do
    original_env = ENV["OPENAI_API_BASE"]

    ENV["OPENAI_API_BASE"] = "https://custom-proxy.example.com/v1"
    result = VCRURLRewriter.send(:actual_api_url)

    assert_equal "https://custom-proxy.example.com/v1", result
  ensure
    ENV["OPENAI_API_BASE"] = original_env
  end

  test "actual_api_url returns default when ENV not set" do
    original_env = ENV["OPENAI_API_BASE"]

    ENV.delete("OPENAI_API_BASE")
    result = VCRURLRewriter.send(:actual_api_url)

    assert_equal "https://api.openai.com/v1", result
  ensure
    ENV["OPENAI_API_BASE"] = original_env
  end

  test "actual_api_url strips trailing slash" do
    original_env = ENV["OPENAI_API_BASE"]

    ENV["OPENAI_API_BASE"] = "https://example.com/v1/"
    result = VCRURLRewriter.send(:actual_api_url)

    assert_equal "https://example.com/v1", result
  ensure
    ENV["OPENAI_API_BASE"] = original_env
  end

  private

  def create_test_cassette(uri)
    cassette_path = File.join(@temp_dir, "test_cassette.yml")
    cassette_content = {
      "http_interactions" => [
        {
          "request" => {
            "uri" => uri,
            "method" => "post",
            "headers" => {
              "Authorization" => ["Bearer test-key"],
            },
          },
          "response" => {
            "status" => { "code" => 200 },
            "headers" => {
              "Content-Type" => ["application/json"],
            },
            "body" => { "string" => '{"test": "data"}' },
          },
        },
      ],
    }

    File.write(cassette_path, YAML.dump(cassette_content))
    cassette_path
  end
end
