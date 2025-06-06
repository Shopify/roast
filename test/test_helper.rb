# frozen_string_literal: true

# Load path setup
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# Project requires
require "roast"

# Standard library requires
require "tmpdir"

# Third-party gem requires
require "active_support/test_case"
require "minitest/autorun"
require "minitest/rg"
require "mocha/minitest"
require "vcr"
require "webmock/minitest"

# Test support files
require "support/fixture_helpers"
require "support/improved_assertions"

# Turn on color during CI since GitHub Actions supports it
if ENV["CI"]
  Minitest::RG.rg!(color: true)
end

# Block all real HTTP requests in tests
WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into(:webmock)
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    match_requests_on: [:method, :host],
  }
end
