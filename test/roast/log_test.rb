# frozen_string_literal: true

require "test_helper"

class LogTest < ActiveSupport::TestCase
  setup do
    Roast::Log.reset!
  end

  teardown do
    Roast::Log.reset!
  end

  test "allows custom logger" do
    custom_output = StringIO.new
    custom_logger = Logger.new(custom_output)

    Roast::Log.logger = custom_logger
    Roast::Log.info("custom logger test")

    assert_includes custom_output.string, "custom logger test"
  end

  test "reset! clears the logger" do
    custom_output = StringIO.new
    Roast::Log.logger = Logger.new(custom_output)

    Roast::Log.reset!

    _stdout, stderr = capture_io do
      Roast::Log.info("after reset")
    end

    refute_includes custom_output.string, "after reset"
    assert_includes stderr, "after reset"
  end

  test "raises ArgumentError for invalid log level" do
    assert_raises(ArgumentError) do
      with_log_level("INVALID") do
        capture_io do
          Roast::Log.info("test")
        end
      end
    end
  end

  private

  def with_log_level(level)
    Roast::Log.reset!
    original_level = ENV["ROAST_LOG_LEVEL"]
    ENV["ROAST_LOG_LEVEL"] = level
    yield
  ensure
    ENV["ROAST_LOG_LEVEL"] = original_level
    Roast::Log.reset!
  end
end
