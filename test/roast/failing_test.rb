# frozen_string_literal: true

require "test_helper"

class FailingTest < ActiveSupport::TestCase
  def test_fails
    flunk("This is an intentional failure")
  end
end
