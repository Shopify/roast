# frozen_string_literal: true

require "test_helper"

module Roast
  module Helpers
    class FunctionCacheTest < ActiveSupport::TestCase
      def test_for_workflow_creates_unique_namespace
        workflow_name = "test_workflow"
        workflow_path = "/path/to/workflow.yml"
        Digest::MD5.hexdigest(workflow_path).first(4)

        cache1 = FunctionCache.for_workflow(workflow_name, workflow_path)
        cache2 = FunctionCache.for_workflow(workflow_name, workflow_path)

        # Should return the same cache instance for the same workflow
        assert_instance_of(ActiveSupport::Cache::FileStore, cache1)
        assert_instance_of(ActiveSupport::Cache::FileStore, cache2)
      end

      def test_for_namespace_returns_file_store_cache_instance
        with_fake_dot_roast_dir do
          cache = FunctionCache.for_namespace("test_namespace")
          assert_instance_of(ActiveSupport::Cache::FileStore, cache)
        end
      end

      def test_path_returns_cache_directory_in_dot_roast
        with_fake_dot_roast_dir do
          expected_path = File.join(Roast.dot_roast_dir, "cache")
          assert_equal(expected_path, FunctionCache.path)
        end
      end

      def test_ensure_exists_creates_cache_directory
        with_fake_dot_roast_dir do
          cache_path = FunctionCache.path
          FileUtils.rm_rf(cache_path) if File.exist?(cache_path)

          FunctionCache.ensure_exists

          assert(File.directory?(cache_path))
        end
      end

      def test_ensure_exists_does_not_fail_if_directory_already_exists
        with_fake_dot_roast_dir do
          cache_path = FunctionCache.path
          FileUtils.mkdir_p(cache_path)

          assert_nothing_raised do
            FunctionCache.ensure_exists
          end
        end
      end

      def test_ensure_gitignore_exists_creates_gitignore_file
        with_fake_dot_roast_dir do
          FunctionCache.ensure_exists
          gitignore_path = FunctionCache.gitignore_path

          File.delete(gitignore_path) if File.exist?(gitignore_path)

          FunctionCache.ensure_gitignore_exists

          assert(File.exist?(gitignore_path))
          assert_equal("*", File.read(gitignore_path))
        end
      end

      def test_ensure_gitignore_exists_does_not_overwrite_existing_file
        with_fake_dot_roast_dir do
          FunctionCache.ensure_exists
          gitignore_path = FunctionCache.gitignore_path
          custom_content = "custom gitignore content"

          File.write(gitignore_path, custom_content)

          FunctionCache.ensure_gitignore_exists

          assert_equal(custom_content, File.read(gitignore_path))
        end
      end

      def test_path_for_namespace_returns_namespaced_path
        with_fake_dot_roast_dir do
          base_path = FunctionCache.path
          namespace = "test_namespace"
          expected_path = File.join(base_path, namespace)

          assert_equal(expected_path, FunctionCache.path_for_namespace(namespace))
        end
      end

      def test_path_for_namespace_returns_base_path_for_empty_namespace
        with_fake_dot_roast_dir do
          base_path = FunctionCache.path
          expected_path = base_path

          assert_equal(expected_path, FunctionCache.path_for_namespace(""))
        end
      end

      def test_namespace_from_workflow_returns_sanitized_name_and_sha
        workflow_name = "Test Workflow"
        workflow_path = "/path/to/workflow.yml"
        expected_namespace = "test_workflow_#{Digest::MD5.hexdigest(workflow_path).first(4)}"
        assert_equal(expected_namespace, FunctionCache.namespace_from_workflow(workflow_name, workflow_path))
      end

      private

      def with_fake_dot_roast_dir
        Dir.mktmpdir do |tmpdir|
          Roast.stubs(:dot_roast_dir).returns(tmpdir)
          yield
        end
      end
    end
  end
end
