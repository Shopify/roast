# frozen_string_literal: true

require "test_helper"
require "roast/tools/write_file"
require "fileutils"

class RoastToolsWriteFileTest < ActiveSupport::TestCase
  def setup
    @temp_dir = File.join(Dir.pwd, "test", "tmp", "write_file_test_dir_#{Time.now.to_i}")
    @test_file_path = File.join(@temp_dir, "test_file.txt")
    @relative_test_file_path = @test_file_path.sub("#{Dir.pwd}/", "")
    FileUtils.mkdir_p(@temp_dir)
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if File.exist?(@temp_dir)
  end

  test ".call creates file with content" do
    content = "test content"
    result = Roast::Tools::WriteFile.call(@relative_test_file_path, content)

    assert File.exist?(@test_file_path), "File should exist after write"
    assert_equal content, File.read(@test_file_path)
    assert_match(/Successfully wrote 1 lines to/, result)
  end

  test ".call creates directories if needed" do
    nested_dir = File.join(@temp_dir, "nested", "dir")
    nested_file = File.join(nested_dir, "test_file.txt")
    relative_nested_file = nested_file.sub("#{Dir.pwd}/", "")
    content = "nested content"

    Roast::Tools::WriteFile.call(relative_nested_file, content)

    assert File.exist?(nested_file), "Nested file should exist after write"
    assert_equal content, File.read(nested_file)
  end

  test ".call overwrites existing file" do
    FileUtils.mkdir_p(File.dirname(@test_file_path))
    File.write(@test_file_path, "original content")

    new_content = "new content"
    Roast::Tools::WriteFile.call(@relative_test_file_path, new_content)

    assert_equal new_content, File.read(@test_file_path)
  end

  test ".call returns error for invalid path" do
    result = Roast::Tools::WriteFile.call("invalid/path.txt", "content")
    assert_equal "Error: Path must start with 'test/' to use the write_file tool, try again.", result
  end

  test ".call handles permission errors" do
    FileUtils.mkdir_p(File.dirname(@test_file_path))
    FileUtils.chmod(0o000, File.dirname(@test_file_path))

    result = Roast::Tools::WriteFile.call(@relative_test_file_path, "content")
    assert_match(/Error writing file: Permission denied/, result)
  ensure
    FileUtils.chmod(0o755, File.dirname(@test_file_path))
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
    Roast::Tools::WriteFile.included(DummyBaseClass)
    assert DummyBaseClass.function_called, "Function should be called on inclusion"
    assert_equal :write_file, DummyBaseClass.function_name
  end
end
