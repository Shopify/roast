# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the individual cog input blocks within the `execute` block of a workflow definition are evaluated
    class CogInputContext
      include SystemCogs::Call::InputContext
      include SystemCogs::Map::InputContext
      include SystemCogs::Repeat::InputContext

      class CogInputContextError < Roast::Error; end
      class ContextNotFoundError < CogInputContextError; end

      #: (?String?) -> void
      def skip!(message = nil)
        raise ControlFlow::SkipCog, message
      end

      #: (?String?) -> void
      def fail!(message = nil)
        raise ControlFlow::FailCog, message
      end

      #: (?String?) -> void
      def break!(message = nil)
        raise ControlFlow::BreakLoop, message
      end

      #: (String, ?Hash) -> String
      def template(path, args = {})
        path = "prompts/#{path}.md.erb" unless File.exist?(path)
        fail!("The prompt #{path} could not be found") unless File.exist?(path)

        ERB.new(File.read(path)).result_with_hash(args)
      end
    end
  end
end
