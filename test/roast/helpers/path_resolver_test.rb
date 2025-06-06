# frozen_string_literal: true

require "test_helper"

class PathResolverTest < ActiveSupport::TestCase
  def setup
    @temp_dir = File.join(Dir.pwd, "tmp", "path_resolver_test")
    @project_dir = File.join(@temp_dir, "project")
    @src_dir = File.join(@project_dir, "src")
    @lib_dir = File.join(@src_dir, "lib")
    @test_dir = File.join(@project_dir, "test")
    @test_file = File.join(@test_dir, "test_file.rb")
    @lib_file = File.join(@lib_dir, "lib_file.rb")
    @original_dir = Dir.pwd

    # Create a temporary directory structure for testing path resolution
    FileUtils.mkdir_p(@lib_dir)
    FileUtils.mkdir_p(@test_dir)

    # Create the test files
    File.write(@test_file, "# Test file")
    File.write(@lib_file, "# Lib file")
  end

  def teardown
    # Return to the original directory
    Dir.chdir(@original_dir) if Dir.pwd != @original_dir

    # Clean up our temp directory
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  test "resolves duplicate path segments" do
    # Create a path with duplicated segments
    duplicated_path = @lib_file.gsub(@temp_dir, "#{@temp_dir}/#{File.basename(@temp_dir)}")

    # Test that our path resolver removes the duplicates
    resolved = Roast::Helpers::PathResolver.resolve(duplicated_path)
    assert_equal @lib_file, resolved
  end

  test "resolves paths from parent directory" do
    Dir.chdir(@src_dir) do
      # Try to resolve a path that's relative to a different directory
      relative_path = "../test/test_file.rb"
      resolved = Roast::Helpers::PathResolver.resolve(relative_path)
      assert_equal @test_file, resolved
    end
  end

  test "resolves paths from different working directory" do
    Dir.chdir(@lib_dir) do
      # Resolve a path to the test file
      resolved = Roast::Helpers::PathResolver.resolve(@test_file)
      assert_equal @test_file, resolved
    end
  end

  test "resolves paths with common root" do
    Dir.chdir(@project_dir) do
      resolved = Roast::Helpers::PathResolver.resolve("src/lib/lib_file.rb")
      assert_equal @lib_file, resolved
    end
  end

  test "handles nonexistent files" do
    nonexistent = File.join(@project_dir, "nonexistent.rb")
    resolved = Roast::Helpers::PathResolver.resolve(nonexistent)
    assert_equal nonexistent, resolved
  end
end
