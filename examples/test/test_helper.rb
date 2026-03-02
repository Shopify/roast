# frozen_string_literal: true

# Example test_helper.rb for testing Roast workflows.
#
# Copy this file into your project's test/ directory and adjust paths as needed.

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))

require "roast"
require "minitest/autorun"

# Optional: Uncomment the following lines if you want VCR recording/playback.
# This lets you record real API responses once, then replay them for fast, offline tests.
#
# require "vcr"
# require "webmock"

require "roast/testing/workflow_test"
