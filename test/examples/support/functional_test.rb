# frozen_string_literal: true

require "roast/testing/test_case"

module Examples
  # Thin wrapper around Roast::Testing::TestCase for internal example tests.
  # New tests should use Roast::Testing::TestCase directly.
  class FunctionalTest < Roast::Testing::TestCase
    self.workflow_dir = File.join(Dir.pwd, "examples")
  end
end
