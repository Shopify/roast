# typed: false
# frozen_string_literal: true

module RuboCop
  module Cop
    module Roast
      # Prevents nesting classes or modules inside reopened (non-test) class
      # definitions in test files.
      #
      # When a class is reopened in a test file (e.g., `class Agent < Cog`) and
      # contains nested class or module definitions, IDE test runners like
      # RubyMine fail to discover test suites. Use `::` scoping instead.
      #
      # The cop walks the entire subtree of the offending class, so deeply
      # nested structures (e.g., `class Agent < Cog; module Providers; ...`)
      # are caught even when the nested definitions are not direct children.
      #
      # Classes nested inside test classes are exempt — helper stubs and
      # fixtures defined inside a test suite are perfectly fine.
      #
      # @example Bad — reopened class with nested module
      #   class Agent < Cog
      #     module Providers
      #       class Claude::MessageTest < ActiveSupport::TestCase
      #         # ...
      #       end
      #     end
      #   end
      #
      # @example Bad — reopened class with nested test class
      #   class Agent < Cog
      #     class ConfigTest < ActiveSupport::TestCase
      #       # ...
      #     end
      #   end
      #
      # @example Good — :: scoping, no class reopening
      #   module Agent::Providers
      #     class Claude::MessageTest < ActiveSupport::TestCase
      #       # ...
      #     end
      #   end
      #
      # @example Good — :: scoped test class
      #   class Agent::ConfigTest < ActiveSupport::TestCase
      #     # ...
      #   end
      #
      # @example Good — helper class inside a test class
      #   class Agent::OutputTest < ActiveSupport::TestCase
      #     class FakeAdapter
      #       def call; end
      #     end
      #   end
      #
      class NoTestClassNesting < Base
        MSG = "Do not nest classes or modules inside reopened class `%<parent>s` in test files. " \
          "Use `::` scoping instead (e.g., `class %<parent>s::Nested` or `module %<parent>s::Nested`)."

        # @!method test_base_class?(node)
        def_node_matcher :test_base_class?, <<~PATTERN
          {
            (const (const {nil? cbase} :ActiveSupport) :TestCase)
            (const (const {nil? cbase} :Minitest) :Test)
            (const {nil? cbase} :Minitest)
          }
        PATTERN

        def on_class(node)
          # Test classes are allowed to contain nested definitions (helpers, stubs)
          return if test_class?(node)

          # Classes nested inside a test class are helpers — leave them alone
          return if inside_test_class?(node)

          # Flag if this non-test class contains any nested class or module
          return unless contains_nested_definitions?(node)

          message = format(MSG, parent: node.identifier.const_name)
          add_offense(node.loc.keyword.join(node.identifier.source_range), message: message)
        end

        private

        def test_class?(node)
          node.parent_class && test_base_class?(node.parent_class)
        end

        # Returns true if any ancestor of +node+ is a test class.
        def inside_test_class?(node)
          current = node.parent
          while current
            return true if current.class_type? && test_class?(current)

            current = current.parent
          end
          false
        end

        # Returns true if +node+ contains any nested class or module definition
        # at any depth, excluding those sheltered inside an intermediate test class.
        def contains_nested_definitions?(node)
          node.each_descendant(:class, :module) do |descendant|
            next if sheltered_by_test_class?(descendant, node)

            return true
          end
          false
        end

        # Returns true if there is a test class between +descendant+ and +stop_at+
        # in the ancestor chain — meaning the descendant is a helper inside a test
        # class and should not count as a problematic nested definition.
        def sheltered_by_test_class?(descendant, stop_at)
          current = descendant.parent
          while current && current != stop_at
            return true if current.class_type? && test_class?(current)

            current = current.parent
          end
          false
        end
      end
    end
  end
end
