# frozen_string_literal: true

require "test_helper"

class RoastToolsReadFileTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir("read_file_test_dir")
    @original_dir = Dir.pwd
    FileUtils.touch(File.join(@temp_dir, "test_file.txt"))
    Dir.chdir(@temp_dir)
  end

  def teardown
    Dir.chdir(@original_dir) if Dir.pwd != @original_dir
    FileUtils.remove_entry(@temp_dir) if File.exist?(@temp_dir)
  end

  test ".call returns file contents when reading a file" do
    test_file = "test_file_content.txt"
    File.write(test_file, "test content")

    result = Roast::Tools::ReadFile.call(test_file)
    assert_equal "test content", result

    File.unlink(test_file)
  end

  test ".call returns directory listing when reading a directory" do
    result = Roast::Tools::ReadFile.call(".")
    assert_match(/test_file\.txt/, result)
  end

  test ".call handles errors gracefully" do
    result = Roast::Tools::ReadFile.call("nonexistent_file.txt")
    assert_match(/Error reading file: No such file or directory/, result)
  end

  test ".call handles both relative and absolute paths" do
    # Create a test file
    test_file = "test_relative_path.txt"
    File.write(test_file, "relative path content")

    # Test with relative path
    relative_result = Roast::Tools::ReadFile.call(test_file)
    assert_equal "relative path content", relative_result

    # Test with absolute path
    absolute_path = File.expand_path(test_file)
    absolute_result = Roast::Tools::ReadFile.call(absolute_path)
    assert_equal "relative path content", absolute_result

    # Clean up
    File.unlink(test_file)
  end

  class DummyBaseClass
    class << self
      attr_reader :function_called, :function_name, :function_description, :function_params, :function_block

      def function(name, description, **params, &block)
        @function_called = true
        @function_name = name
        @function_description = description
        @function_params = params
        @function_block = block
      end
    end
  end

  test ".included adds function to the base class" do
    Roast::Tools::ReadFile.included(DummyBaseClass)
    assert DummyBaseClass.function_called, "Expected function_called to be true"
    assert_equal :read_file, DummyBaseClass.function_name
  end
end
