# frozen_string_literal: true

require "test_helper"

class RoastToolsGrepTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir("grep_test_dir")
    @test_file1 = File.join(@temp_dir, "test_file1.txt")
    @test_file2 = File.join(@temp_dir, "nested", "test_file2.txt")
    @original_dir = Dir.pwd

    FileUtils.mkdir_p(File.dirname(@test_file1))
    FileUtils.mkdir_p(File.dirname(@test_file2))

    File.write(
      @test_file1,
      "This is a test file with some content\nIt has multiple lines\nAnd some searchable text",
    )
    File.write(@test_file2, "Another test file\nWith different content\nBut also searchable")

    Dir.chdir(@temp_dir)
  end

  def teardown
    Dir.chdir(@original_dir) if Dir.pwd != @original_dir
    FileUtils.remove_entry(@temp_dir) if File.exist?(@temp_dir)
  end

  test "searches for string using ripgrep" do
    result = Roast::Tools::Grep.call("searchable")

    # Should find the string in both test files
    assert_match(/test_file1\.txt/, result)
    assert_match(/test_file2\.txt/, result)
    assert_match(/searchable/, result)
  end

  test "handles errors gracefully" do
    # Mock Open3 to simulate a command failure
    Open3.stub(:capture3, ->(*_args) { raise StandardError, "Command failed" }) do
      result = Roast::Tools::Grep.call("searchable")
      assert_equal("Error grepping for string: Command failed", result)
    end
  end

  test "handles curly braces in search string" do
    # Create a file with curly braces in content
    File.write(File.join(@temp_dir, "react_file.js"), "import {render} from 'react'")

    result = Roast::Tools::Grep.call("import {render}")

    # Should find the string without issues (no escaping needed with -F flag)
    assert_match(/react_file\.js/, result)
    assert_match(/import {render}/, result)
  end

  test "limits output to MAX_RESULT_LINES" do
    # Create many files to exceed the line limit
    100.times do |i|
      File.write(File.join(@temp_dir, "file#{i}.txt"), "searchable content\nmore lines\n")
    end

    result = Roast::Tools::Grep.call("searchable")

    # Should be truncated
    assert_match(/truncated to 100 lines/, result)
  end

  test ".included adds function to the base class" do
    base_class = Class.new do
      class << self
        attr_reader :function_name, :function_called

        def function(name, description, **params, &block)
          @function_called = true
          @function_name = name
          @function_description = description
          @function_params = params
          @function_block = block
        end
      end
    end

    Roast::Tools::Grep.included(base_class)

    assert base_class.function_called, "Expected function to be called"
    assert_equal :grep, base_class.function_name
  end
end
