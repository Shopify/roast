# frozen_string_literal: true

require "test_helper"

class MetadataAccessTest < ActiveSupport::TestCase
  class TestClass
    include Roast::Helpers::MetadataAccess
  end

  def setup
    @test_object = TestClass.new
    @metadata = {}
    Thread.current[:workflow_metadata] = @metadata
    Thread.current[:current_step_name] = "test_step"
    Roast::Helpers::Logger.reset
  end

  def teardown
    Thread.current[:workflow_metadata] = nil
    Thread.current[:current_step_name] = nil
  end

  test "step_metadata returns metadata for current step" do
    @metadata["test_step"] = { "key" => "value" }

    result = @test_object.step_metadata
    assert_equal({ "key" => "value" }, result)
  end

  test "step_metadata returns metadata for specified step" do
    @metadata["other_step"] = { "other_key" => "other_value" }

    result = @test_object.step_metadata("other_step")
    assert_equal({ "other_key" => "other_value" }, result)
  end

  test "step_metadata returns empty hash when step has no metadata" do
    result = @test_object.step_metadata("nonexistent_step")
    assert_equal({}, result)
  end

  test "step_metadata returns empty hash when no step name" do
    Thread.current[:current_step_name] = nil

    out, _ = capture_io do
      assert_equal({}, @test_object.step_metadata)
    end

    assert_match(/WARN: MetadataAccess#current_step_name is not present/, out)
  end

  test "step_metadata returns empty hash and logs warning when workflow_metadata is nil" do
    Thread.current[:workflow_metadata] = nil

    out, _ = capture_io do
      assert_equal({}, @test_object.step_metadata)
    end

    assert_match(/WARN: MetadataAccess#workflow_metadata is not present/, out)
  end

  test "set_current_step_metadata sets metadata for current step" do
    @test_object.set_current_step_metadata("duration_ms", 150)

    assert_equal({ "duration_ms" => 150 }, @metadata["test_step"])
  end

  test "set_current_step_metadata creates step metadata if not exists" do
    assert_nil @metadata["test_step"]

    @test_object.set_current_step_metadata("new_key", "new_value")

    assert_equal({ "new_key" => "new_value" }, @metadata["test_step"])
  end

  test "set_current_step_metadata adds to existing metadata" do
    @metadata["test_step"] = { "existing" => "data" }

    @test_object.set_current_step_metadata("new_key", "new_value")

    assert_equal(
      {
        "existing" => "data",
        "new_key" => "new_value",
      },
      @metadata["test_step"],
    )
  end

  test "set_current_step_metadata returns early when no step name" do
    Thread.current[:current_step_name] = nil

    out, _ = capture_io do
      @test_object.set_current_step_metadata("key", "value")
    end

    # Should not modify metadata
    assert_equal({}, @metadata)
    assert_match(/WARN: MetadataAccess#current_step_name is not present/, out)
  end

  test "set_current_step_metadata returns early when no workflow metadata" do
    Thread.current[:workflow_metadata] = nil

    out, _ = capture_io do
      @test_object.set_current_step_metadata("key", "value")
    end

    # Should not raise error
    assert_nil Thread.current[:workflow_metadata]
    assert_match(/WARN: MetadataAccess#workflow_metadata is not present/, out)
  end

  test "workflow_metadata is private" do
    assert_raises(NoMethodError) { @test_object.workflow_metadata }
  end

  test "current_step_name is private" do
    assert_raises(NoMethodError) { @test_object.current_step_name }
  end

  test "metadata access works with symbols and strings" do
    # HashWithIndifferentAccess behavior
    metadata = ActiveSupport::HashWithIndifferentAccess.new
    Thread.current[:workflow_metadata] = metadata

    @test_object.set_current_step_metadata(:symbol_key, "value1")
    @test_object.set_current_step_metadata("string_key", "value2")

    result = @test_object.step_metadata
    assert_equal "value1", result[:symbol_key]
    assert_equal "value1", result["symbol_key"]
    assert_equal "value2", result[:string_key]
    assert_equal "value2", result["string_key"]
  end
end
