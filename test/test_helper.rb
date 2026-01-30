# frozen_string_literal: true

# Load path setup
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "simplecov"
SimpleCov.start

# Project requires
require "roast"

# Standard library requires
require "tmpdir"

# Third-party gem requires
require "active_support/test_case"
require "minitest/autorun"
require "minitest/rg"
require "mocha/minitest"
# Test support files
require "support/improved_assertions"
require "examples/support/functional_test"
require "vcr"
require "webmock"

# Turn on color during CI since GitHub Actions supports it
if ENV["CI"]
  Minitest::RG.rg!(color: true)
end

def slow_test!
  skip "slow test" unless ["1", "true"].include?(ENV["ROAST_RUN_SLOW_TESTS"])
end

def with_log_level(level)
  Roast::Log.reset!
  original_level = ENV["ROAST_LOG_LEVEL"]
  ENV["ROAST_LOG_LEVEL"] = level
  yield
ensure
  ENV["ROAST_LOG_LEVEL"] = original_level
  Roast::Log.reset!
end

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock

  config.filter_sensitive_data("http://mytestingproxy.local/v1/chat/completions") do |interaction|
    interaction.request.uri
  end

  config.filter_sensitive_data("my-token") do |interaction|
    interaction.request.headers["Authorization"].first
  end

  config.filter_sensitive_data("<FILTERED>") do |interaction|
    interaction.request.headers["Set-Cookie"]
  end

  config.filter_sensitive_data("<FILTERED>") do |interaction|
    interaction.response.headers["Set-Cookie"]
  end
end
