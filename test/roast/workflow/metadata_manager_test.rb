# frozen_string_literal: true

require "test_helper"

class MetadataManagerTest < ActiveSupport::TestCase
  def setup
    @manager = Roast::Workflow::MetadataManager.new
  end

  test "initializes with empty metadata" do
    assert_equal({}, @manager.to_h)
    assert_instance_of Roast::Workflow::DotAccessHash, @manager.metadata
  end

  test "metadata accessor returns DotAccessHash wrapper" do
    metadata = @manager.metadata
    assert_instance_of Roast::Workflow::DotAccessHash, metadata

    # Test dot notation access
    @manager.metadata["step1"] = { "key" => "value" }
    assert_equal "value", metadata.step1.key
  end

  test "metadata= sets new metadata and resets wrapper" do
    original_wrapper = @manager.metadata

    @manager.metadata = { "new" => "data" }

    # Should have new wrapper instance
    refute_same original_wrapper, @manager.metadata
    assert_equal({ "new" => "data" }, @manager.to_h)
  end

  test "metadata= converts regular hash to HashWithIndifferentAccess" do
    @manager.metadata = { "key" => "value" }

    # Should work with both string and symbol keys
    assert_equal "value", @manager.raw_metadata["key"]
    assert_equal "value", @manager.raw_metadata[:key]
  end

  test "raw_metadata returns underlying hash" do
    @manager.metadata["test"] = "value"

    raw = @manager.raw_metadata
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, raw
    assert_equal({ "test" => "value" }, raw)
  end

  test "to_h returns plain hash representation" do
    @manager.metadata["step1"] = { "duration" => 100 }
    @manager.metadata["step2"] = { "success" => true }

    hash = @manager.to_h
    assert_instance_of Hash, hash
    assert_equal(
      {
        "step1" => { "duration" => 100 },
        "step2" => { "success" => true },
      },
      hash,
    )
  end

  test "from_h restores metadata from hash" do
    data = {
      "step1" => { "key1" => "value1" },
      "step2" => { "key2" => "value2" },
    }

    @manager.from_h(data)

    assert_equal data, @manager.to_h
    assert_equal "value1", @manager.metadata.step1.key1
    assert_equal "value2", @manager.metadata.step2.key2
  end

  test "from_h handles nil gracefully" do
    @manager.metadata["existing"] = "data"
    @manager.from_h(nil)

    # Should not change existing data
    assert_equal({ "existing" => "data" }, @manager.to_h)
  end

  test "metadata maintains nested structure" do
    @manager.metadata["step1"] = {}
    @manager.metadata["step1"]["metrics"] = {}
    @manager.metadata["step1"]["metrics"]["duration_ms"] = 150
    @manager.metadata["step1"]["metrics"]["api_calls"] = 3

    assert_equal 150, @manager.metadata.step1.metrics.duration_ms
    assert_equal 3, @manager.metadata.step1.metrics.api_calls
  end

  test "metadata changes are reflected in to_h" do
    @manager.metadata["dynamic"] = "initial"
    assert_equal({ "dynamic" => "initial" }, @manager.to_h)

    @manager.metadata["dynamic"] = "updated"
    assert_equal({ "dynamic" => "updated" }, @manager.to_h)

    @manager.metadata["new_key"] = "new_value"
    assert_equal(
      {
        "dynamic" => "updated",
        "new_key" => "new_value",
      },
      @manager.to_h,
    )
  end
end
