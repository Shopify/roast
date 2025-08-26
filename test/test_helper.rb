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

# Turn on color during CI since GitHub Actions supports it
if ENV["CI"]
  Minitest::RG.rg!(color: true)
end

# Helper method to create a properly stubbed mock workflow
def create_mock_workflow(options = {})
  workflow = mock("workflow")
  default_stubs = {
    output: {},
    pause_step_name: nil,
    verbose: false,
    storage_type: nil, # This is the key fix for test failures
  }
  workflow.stubs(default_stubs.merge(options))
  workflow
end
