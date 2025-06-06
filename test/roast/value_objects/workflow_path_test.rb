# frozen_string_literal: true

require "test_helper"

module Roast
  module ValueObjects
    class WorkflowPathTest < ActiveSupport::TestCase
      def test_initialization_with_valid_yml_path
        path = WorkflowPath.new("/path/to/workflow.yml")
        assert_equal("/path/to/workflow.yml", path.value)
      end

      def test_initialization_with_valid_yaml_path
        path = WorkflowPath.new("/path/to/workflow.yaml")
        assert_equal("/path/to/workflow.yaml", path.value)
      end

      def test_initialization_strips_whitespace
        path = WorkflowPath.new("  /path/to/workflow.yml  ")
        assert_equal("/path/to/workflow.yml", path.value)
      end

      def test_initialization_with_empty_string_raises_error
        assert_raises(WorkflowPath::InvalidPathError) do
          WorkflowPath.new("")
        end
      end

      def test_initialization_with_whitespace_only_raises_error
        assert_raises(WorkflowPath::InvalidPathError) do
          WorkflowPath.new("   ")
        end
      end

      def test_initialization_without_yml_extension_raises_error
        assert_raises(WorkflowPath::InvalidPathError) do
          WorkflowPath.new("/path/to/workflow.txt")
        end
      end

      def test_exist_method
        # Create a temporary file for testing
        Dir.mktmpdir do |dir|
          existing_file = File.join(dir, "workflow.yml")
          File.write(existing_file, "test")

          existing_path = WorkflowPath.new(existing_file)
          assert(existing_path.exist?)

          non_existing_path = WorkflowPath.new("/non/existing/path.yml")
          refute(non_existing_path.exist?)
        end
      end

      def test_absolute_and_relative_methods
        absolute_path = WorkflowPath.new("/absolute/path/workflow.yml")
        assert(absolute_path.absolute?)
        refute(absolute_path.relative?)

        relative_path = WorkflowPath.new("relative/path/workflow.yml")
        refute(relative_path.absolute?)
        assert(relative_path.relative?)
      end

      def test_dirname_method
        path = WorkflowPath.new("/path/to/workflow.yml")
        assert_equal("/path/to", path.dirname)
      end

      def test_basename_method
        path = WorkflowPath.new("/path/to/workflow.yml")
        assert_equal("workflow.yml", path.basename)
      end

      def test_to_s_and_to_path_return_value
        path = WorkflowPath.new("/path/to/workflow.yml")
        assert_equal("/path/to/workflow.yml", path.to_s)
        assert_equal("/path/to/workflow.yml", path.to_path)
      end

      def test_equality
        path1 = WorkflowPath.new("/path/to/workflow.yml")
        path2 = WorkflowPath.new("/path/to/workflow.yml")
        path3 = WorkflowPath.new("/different/workflow.yml")

        assert_equal(path1, path2)
        refute_equal(path1, path3)
        refute_equal(path1, "/path/to/workflow.yml")
        refute_equal(path1, nil)
      end

      def test_eql_method
        path1 = WorkflowPath.new("/path/to/workflow.yml")
        path2 = WorkflowPath.new("/path/to/workflow.yml")

        assert(path1.eql?(path2))
      end

      def test_hash_equality
        path1 = WorkflowPath.new("/path/to/workflow.yml")
        path2 = WorkflowPath.new("/path/to/workflow.yml")
        path3 = WorkflowPath.new("/different/workflow.yml")

        assert_equal(path1.hash, path2.hash)
        refute_equal(path1.hash, path3.hash)
      end

      def test_can_be_used_as_hash_key
        hash = {}
        path1 = WorkflowPath.new("/path/to/workflow.yml")
        path2 = WorkflowPath.new("/path/to/workflow.yml")

        hash[path1] = "value"
        assert_equal("value", hash[path2])
      end

      def test_frozen_after_initialization
        path = WorkflowPath.new("/path/to/workflow.yml")
        assert(path.frozen?)
      end
    end
  end
end
