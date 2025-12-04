# typed: true
# frozen_string_literal: true

module RuboCop
  module Cop
    module Roast
      # Cop that enforces use of Roast::Log instead of bare puts calls
      #
      # @example
      #   # bad
      #   puts "Hello world"
      #   $stderr.puts "Error message"
      #   $stdout.puts "Output"
      #
      #   # good
      #   Roast::Log.info("Hello world")
      #   Roast::Log.error("Error message")
      #   Roast::Log.info("Output")
      #
      class UseRoastLog < Base
        MSG = "Use `Roast::Log` instead of `%<method>s` for consistent logging."

        RESTRICT_ON_SEND = [:puts].freeze

        def on_send(node)
          return unless puts_call?(node)
          return if allowed_context?(node)

          method_name = format_method_name(node)
          add_offense(node, message: format(MSG, method: method_name))
        end

        private

        def puts_call?(node)
          node.method_name == :puts
        end

        def format_method_name(node)
          if node.receiver
            "#{node.receiver.source}.puts"
          else
            "puts"
          end
        end

        def allowed_context?(node)
          # Allow puts in test files
          return true if test_file?

          # Allow puts in initializers (they may need to output before logger is ready)
          return true if initializer_file?

          # Allow puts in DSL examples
          return true if dsl_file?

          false
        end

        def test_file?
          processed_source.file_path.include?("/test/")
        end

        def initializer_file?
          processed_source.file_path.include?("/.roast/initializers/") ||
            processed_source.file_path.include?("/test/fixtures/initializers/")
        end

        def dsl_file?
          processed_source.file_path.include?("/dsl/") &&
            !processed_source.file_path.include?("/lib/roast/dsl/")
        end
      end
    end
  end
end
