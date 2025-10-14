# frozen_string_literal: true

require "test_helper"

module Roast
  class ErrorTest < ActiveSupport::TestCase
    test "Roast::Error inherits from StandardError" do
      assert_equal StandardError, Roast::Error.superclass
    end

    test "Roast::Graph::Error inherits from Roast::Error" do
      assert_equal Roast::Error, Roast::Graph::Error.superclass
    end

    test "Roast::Graph::AddEdgeError inherits from Roast::Graph::Error" do
      assert_equal Roast::Graph::Error, Roast::Graph::AddEdgeError.superclass
    end

    test "Roast::Graph::EdgeTopologyError inherits from Roast::Graph::Error" do
      assert_equal Roast::Graph::Error, Roast::Graph::EdgeTopologyError.superclass
    end

    test "all Roast errors are catchable with Roast::Error" do
      assert_raises(Roast::Error) do
        raise Roast::Graph::AddEdgeError, "test error"
      end
    end
  end
end
