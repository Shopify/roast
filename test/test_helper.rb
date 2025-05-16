# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require "cgi"
require "vcr"

require "active_support/test_case"

# not sure why this workaround is needed
def ActiveSupport.test_order = :random

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# Require the main file
require "roast"

module Minitest
  class << self
    alias_method :at_exit, :original_at_exit
  end
end

# Require test helpers
require_relative "support/fixture_helpers"
require_relative "support/improved_assertions"

require "webmock/minitest"
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
