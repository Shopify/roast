# frozen_string_literal: true

require "test_helper"

class ApiResourceTest < ActiveSupport::TestCase
  def setup
    @simple_url = "https://api.example.com/data"
    @fetch_style_config = {
      url: "https://api.example.com/resource",
      options: {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer token123",
        },
        body: {
          query: "search term",
          limit: 10,
        },
      },
    }.to_json
    @original_env = ENV.to_hash
  end

  def teardown
    ENV.replace(@original_env)
  end

  # #config
  test "parses JSON configuration when provided" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    assert_kind_of Hash, resource.config
    assert_equal "https://api.example.com/resource", resource.config["url"]
    assert_kind_of Hash, resource.config["options"]
  end

  test "returns nil for non-JSON targets in config" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_nil resource.config
  end

  # #api_url
  test "extracts URL from config when available" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    assert_equal "https://api.example.com/resource", resource.api_url
  end

  test "uses target as URL when no config is available" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal @simple_url, resource.api_url
  end

  # #options
  test "returns options from config when available" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    assert_kind_of Hash, resource.options
    assert_equal "POST", resource.options["method"]
    assert_includes resource.options["headers"], "Content-Type"
    assert_equal "application/json", resource.options["headers"]["Content-Type"]
  end

  test "returns empty hash when no config is available" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal({}, resource.options)
  end

  # #http_method
  test "returns appropriate Net::HTTP class for specified method" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    assert_equal Net::HTTP::Post, resource.http_method
  end

  test "defaults to GET for simple URLs" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal Net::HTTP::Get, resource.http_method
  end

  test "supports various HTTP methods" do
    methods = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "DELETE" => Net::HTTP::Delete,
      "PATCH" => Net::HTTP::Patch,
      "HEAD" => Net::HTTP::Head,
    }
    methods.each do |method_name, expected_class|
      config = { url: "https://example.com", options: { method: method_name } }.to_json
      resource = Roast::Resources::ApiResource.new(config)
      assert_equal expected_class, resource.http_method, "HTTP method for #{method_name} should be #{expected_class}"
    end
  end

  # #exists?
  test "returns true for successful HTTP responses" do
    mock_response = mock
    mock_response.stubs(:code).returns("200")
    mock_http = mock
    Net::HTTP.stubs(:new).returns(mock_http)
    mock_http.stubs(:use_ssl=)
    mock_http.stubs(:request).returns(mock_response)
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert resource.exists?
  end

  test "returns false for nil target in exists?" do
    resource = Roast::Resources::ApiResource.new(nil)
    refute resource.exists?
  end

  test "returns false for failed HTTP responses" do
    mock_response = mock
    mock_response.stubs(:code).returns("404")
    mock_http = mock
    Net::HTTP.stubs(:new).returns(mock_http)
    mock_http.stubs(:use_ssl=)
    mock_http.stubs(:request).returns(mock_response)
    resource = Roast::Resources::ApiResource.new(@simple_url)
    refute resource.exists?
  end

  test "returns false when HTTP request raises an error" do
    mock_http = mock
    Net::HTTP.stubs(:new).returns(mock_http)
    mock_http.stubs(:use_ssl=)
    mock_http.stubs(:request).raises(Roast::Error.new("Connection failed"))
    resource = Roast::Resources::ApiResource.new(@simple_url)
    refute resource.exists?
  end

  test "substitutes environment variables in headers" do
    ENV["TEST_API_TOKEN"] = "test-token-123"
    config = {
      url: "https://api.example.com/resource",
      options: {
        method: "GET",
        headers: {
          "Authorization": "Bearer ${TEST_API_TOKEN}",
        },
      },
    }.to_json
    mock_response = mock
    mock_response.stubs(:code).returns("200")
    mock_http = mock
    Net::HTTP.stubs(:new).returns(mock_http)
    mock_http.stubs(:use_ssl=)
    mock_http.stubs(:request).returns(mock_response)
    resource = Roast::Resources::ApiResource.new(config)
    assert resource.exists?
  end

  # #contents
  test "returns API response for simple URLs" do
    Net::HTTP.stubs(:get).returns('{"result": "success"}')
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal '{"result": "success"}', resource.contents
  end

  test "returns formatted config for Fetch API style targets" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    result = resource.contents
    assert_kind_of String, result
    parsed = JSON.parse(result)
    assert_equal "https://api.example.com/resource", parsed["url"]
    assert_equal "POST", parsed["method"]
  end

  test "includes environment variables in formatted output" do
    ENV["TEST_API_TOKEN"] = "test-token-123"
    config = {
      url: "https://api.example.com/resource",
      options: {
        method: "GET",
        headers: {
          "Authorization": "Bearer ${TEST_API_TOKEN}",
        },
      },
    }.to_json
    resource = Roast::Resources::ApiResource.new(config)
    result = resource.contents
    parsed = JSON.parse(result)
    assert_includes parsed["headers"], "Authorization"
    assert_equal "Bearer ${TEST_API_TOKEN}", parsed["headers"]["Authorization"]
  end

  test "returns nil for nil target in contents" do
    resource = Roast::Resources::ApiResource.new(nil)
    assert_nil resource.contents
  end

  test "returns nil when HTTP request raises an error in contents" do
    Net::HTTP.stubs(:get).raises(Roast::Error.new("Connection failed"))
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_nil resource.contents
  end

  # #name
  test "includes URL and method for Fetch API style targets" do
    resource = Roast::Resources::ApiResource.new(@fetch_style_config)
    assert_equal "API https://api.example.com/resource (POST)", resource.name
  end

  test "includes URL for simple URL targets" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal "API #{@simple_url}", resource.name
  end

  test "returns default name for nil target" do
    resource = Roast::Resources::ApiResource.new(nil)
    assert_equal "Unnamed API", resource.name
  end

  # #type
  test "always returns :api" do
    resource = Roast::Resources::ApiResource.new(@simple_url)
    assert_equal :api, resource.type
  end
end
