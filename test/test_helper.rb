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
require "support/test_cog"
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

def with_log_level(level, &block)
  Roast::Log.reset!
  with_env("ROAST_LOG_LEVEL", level, &block)
ensure
  Roast::Log.reset!
end

def with_env(key, value)
  original = ENV[key]
  ENV[key] = value
  yield
ensure
  ENV[key] = original
end

# Run a cog through the full async execution path for integration testing.
#
# @param cog [Roast::Cog] The cog instance to run
# @param config [Roast::Cog::Config] Optional config (defaults to cog's config class)
# @param scope_value [Object] Optional executor scope value passed to input proc
# @param scope_index [Integer] Optional executor scope index passed to input proc
# @return [Roast::Cog] The cog after execution completes
def run_cog(cog, config: nil, scope_value: nil, scope_index: 0)
  config ||= cog.class.config_class.new

  Sync do
    barrier = Async::Barrier.new
    input_context = Roast::CogInputContext.new

    cog.run!(barrier, config, input_context, scope_value, scope_index)
    barrier.wait
  end

  cog
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
