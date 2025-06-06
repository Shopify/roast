# frozen_string_literal: true

require "test_helper"

class RoastToolsUpdateFilesTest < ActiveSupport::TestCase
  def setup
    @temp_dir = File.join(Dir.pwd, "test", "tmp", "update_files_test_dir_#{Time.now.to_i}")
    @test_file_path = File.join(@temp_dir, "test_file.txt")
    @test_file2_path = File.join(@temp_dir, "test_file2.txt")
    @nested_dir = File.join(@temp_dir, "nested", "dir")
    @nested_file_path = File.join(@nested_dir, "nested_file.txt")

    FileUtils.mkdir_p(@temp_dir)
    FileUtils.mkdir_p(@nested_dir)

    # Create initial files with content
    File.write(@test_file_path, "line1\nline2\nline3\nline4\n")
    File.write(@test_file2_path, "file2_line1\nfile2_line2\nfile2_line3\n")
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if File.exist?(@temp_dir)
  end

  test ".call applies a simple unified diff to a single file" do
    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,5 @@
       line1
      +inserted line
       line2
       line3
       line4
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Successfully applied patch/, result)
    assert_equal "line1\ninserted line\nline2\nline3\nline4\n", File.read(@test_file_path)
  end

  test ".call applies a unified diff that modifies multiple files" do
    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,4 @@
       line1
      -line2
      +modified line2
       line3
       line4
      --- a/test_file2.txt
      +++ b/test_file2.txt
      @@ -1,3 +1,4 @@
       file2_line1
      +new line in file2
       file2_line2
       file2_line3
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Successfully applied patch to 2 file/, result)
    assert_equal "line1\nmodified line2\nline3\nline4\n", File.read(@test_file_path)
    assert_equal "file2_line1\nnew line in file2\nfile2_line2\nfile2_line3\n", File.read(@test_file2_path)
  end

  test ".call creates a new file when it doesn't exist" do
    diff = <<~DIFF
      --- /dev/null
      +++ b/nested/dir/nested_file.txt
      @@ -0,0 +1,3 @@
      +line1 in new file
      +line2 in new file
      +line3 in new file
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Successfully applied patch/, result)
    assert File.exist?(@nested_file_path)
    assert_equal "line1 in new file\nline2 in new file\nline3 in new file\n", File.read(@nested_file_path)
  end

  test ".call fails when create_files is false and file doesn't exist" do
    diff = <<~DIFF
      --- /dev/null
      +++ b/non_existent_file.txt
      @@ -0,0 +1,2 @@
      +line1
      +line2
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir, nil, false)

    assert_match(/Error: File non_existent_file.txt does not exist/, result)
  end

  test ".call respects path restrictions" do
    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,5 @@
       line1
      +restricted line
       line2
       line3
       line4
    DIFF

    other_dir = File.join(Dir.pwd, "test", "tmp", "other_dir_#{Time.now.to_i}")
    FileUtils.mkdir_p(other_dir)

    # Should fail due to restriction
    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir, other_dir)

    assert_match(/Error: Path test_file.txt must start with/, result)
    assert_equal("line1\nline2\nline3\nline4\n", File.read(@test_file_path)) # File unchanged
  ensure
    FileUtils.remove_entry(other_dir) if File.exist?(other_dir)
  end

  test ".call rolls back changes if a hunk cannot be applied" do
    # Create initial state for both files
    File.write(@test_file_path, "line1\nline2\nline3\nline4\n")
    File.write(@test_file2_path, "file2_line1\nfile2_line2\nfile2_line3\n")

    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,4 @@
       line1
      -line2
      +good change
       line3
       line4
      --- a/test_file2.txt
      +++ b/test_file2.txt
      @@ -1,3 +1,3 @@
       file2_line1
      -non-existing line
      +this won't apply
       file2_line3
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Error applying patch: Hunk could not be applied cleanly/, result)
    # Both files should remain unchanged
    assert_equal "line1\nline2\nline3\nline4\n", File.read(@test_file_path)
    assert_equal "file2_line1\nfile2_line2\nfile2_line3\n", File.read(@test_file2_path)
  end

  test ".call handles deletion of lines" do
    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,3 @@
       line1
      -line2
       line3
       line4
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Successfully applied patch/, result)
    assert_equal "line1\nline3\nline4\n", File.read(@test_file_path)
  end

  test ".call handles complete file replacement" do
    diff = <<~DIFF
      --- a/test_file.txt
      +++ b/test_file.txt
      @@ -1,4 +1,2 @@
      -line1
      -line2
      -line3
      -line4
      +completely
      +new content
    DIFF

    result = Roast::Tools::UpdateFiles.call(diff, @temp_dir)

    assert_match(/Successfully applied patch/, result)
    assert_equal "completely\nnew content\n", File.read(@test_file_path)
  end

  test ".included adds function to the base class" do
    dummy_class = Class.new do
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

    Roast::Tools::UpdateFiles.included(dummy_class)
    assert dummy_class.function_called, "Function should be called on inclusion"
    assert_equal :update_files, dummy_class.function_name
  end
end
