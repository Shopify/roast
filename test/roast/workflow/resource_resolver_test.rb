# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ResourceResolverTest < ActiveSupport::TestCase
      def setup
        @context_path = File.expand_path("test/fixtures/files")
      end

      def test_resolve_returns_none_resource_for_nil_target
        resource = ResourceResolver.resolve(nil, @context_path)
        assert_instance_of(Roast::Resources::NoneResource, resource)
      end

      def test_resolve_returns_none_resource_for_empty_target
        resource = ResourceResolver.resolve("", @context_path)
        assert_instance_of(Roast::Resources::NoneResource, resource)
      end

      def test_resolve_returns_file_resource_for_file_target
        target = "test/fixtures/files/test.rb"
        resource = ResourceResolver.resolve(target, @context_path)
        assert_instance_of(Roast::Resources::FileResource, resource)
        assert_equal(File.expand_path(target), resource.value)
      end

      def test_resolve_returns_directory_resource_for_directory_target
        target = "test/fixtures"
        resource = ResourceResolver.resolve(target, @context_path)
        assert_instance_of(Roast::Resources::DirectoryResource, resource)
        assert_equal(File.expand_path(target), resource.value)
      end

      def test_resolve_returns_url_resource_for_url_target
        target = "https://example.com"
        resource = ResourceResolver.resolve(target, @context_path)
        assert_instance_of(Roast::Resources::UrlResource, resource)
        assert_equal(target, resource.value)
      end

      def test_process_target_expands_file_paths
        target = "test.rb"
        processed = ResourceResolver.process_target(target, @context_path)
        assert_equal(File.expand_path(target), processed)
      end

      def test_process_target_handles_glob_patterns_with_matches
        target = "test/fixtures/files/*.rb"
        processed = ResourceResolver.process_target(target, @context_path)

        # Should return newline-separated list of matched files
        files = processed.split("\n")
        assert(files.any? { |f| f.end_with?("test.rb") })
        assert(files.any? { |f| f.end_with?("subject.rb") })
        assert(files.all? { |f| File.expand_path(f) == f }) # All should be absolute paths
      end

      def test_process_target_handles_glob_patterns_without_matches
        target = "nonexistent/*.xyz"
        processed = ResourceResolver.process_target(target, @context_path)
        assert_equal(target, processed) # Returns pattern itself when no matches
      end

      def test_process_shell_command_with_dollar_syntax
        Open3.expects(:capture2e).with({}, "echo hello").returns(["hello\n", nil])
        result = ResourceResolver.process_shell_command("$(echo hello)")
        assert_equal("hello", result)
      end

      def test_process_shell_command_with_legacy_percent_syntax
        Open3.expects(:capture2e).with({}, "echo", "hello").returns(["hello\n", nil])
        result = ResourceResolver.process_shell_command("% echo hello")
        assert_equal("hello", result)
      end

      def test_process_shell_command_returns_original_for_non_commands
        result = ResourceResolver.process_shell_command("regular string")
        assert_equal("regular string", result)
      end

      def test_process_target_with_shell_command
        Open3.expects(:capture2e).with({}, "pwd").returns(["/home/user\n", nil])
        processed = ResourceResolver.process_target("$(pwd)", @context_path)
        assert_equal(File.expand_path("/home/user"), processed)
      end

      def test_process_target_preserves_simple_processed_commands
        # When a shell command returns a simple result without paths,
        # it should not be expanded to maintain backward compatibility
        Open3.expects(:capture2e).with({}, "echo simple").returns(["simple\n", nil])
        processed = ResourceResolver.process_target("$(echo simple)", @context_path)
        assert_equal("simple", processed)
      end

      def test_resolve_with_shell_command_target
        Open3.expects(:capture2e).with({}, "ls test.rb").returns(["test.rb\n", nil])
        resource = ResourceResolver.resolve("$(ls test.rb)", @context_path)
        assert_instance_of(Roast::Resources::FileResource, resource)
      end
    end
  end
end
