# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class ContextPathResolverTest < ActiveSupport::TestCase
      class TestClass
        def test_method; end
      end

      module TestModule
        class NestedClass
          def nested_method; end
        end
      end

      def test_resolves_simple_class
        path = ContextPathResolver.resolve(TestClass)
        assert(path.end_with?("test/roast/workflow"))
      end

      def test_resolves_namespaced_class
        path = ContextPathResolver.resolve(TestModule::NestedClass)
        assert(path.end_with?("test/roast/workflow"))
      end

      def test_resolves_for_instance
        instance = TestClass.new
        path = ContextPathResolver.resolve_for_instance(instance)
        assert(path.end_with?("test/roast/workflow"))
      end

      def test_handles_class_without_name
        anonymous_class = Class.new
        path = ContextPathResolver.resolve(anonymous_class)
        # Should fall back to current directory
        assert(path.is_a?(String))
        assert(Dir.exist?(path))
      end

      def test_handles_class_not_in_load_path
        # Create a class that won't be found in load path
        unique_class = Class.new do
          class << self
            def name
              "NonExistentModule::UnfindableClass"
            end
          end
        end

        path = ContextPathResolver.resolve(unique_class)
        # Should fall back to some directory
        assert(path.is_a?(String))
        assert(Dir.exist?(path))
      end
    end
  end
end
