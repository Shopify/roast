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
require "support/fixture_helpers"
require "support/improved_assertions"
require "support/functional_test"
require "support/vcr_url_rewriter"
require "dsl/support/functional_test"
require "vcr"
require "webmock"

# Turn on color during CI since GitHub Actions supports it
if ENV["CI"]
  Minitest::RG.rg!(color: true)
end

def slow_test!
  skip "slow test" unless ["1", "true"].include?(ENV["ROAST_RUN_SLOW_TESTS"])
end

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock

  # Apply URL rewriting and scrubbing hooks
  VCRURLRewriter.configure!
end
