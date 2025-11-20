# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which the individual cog input blocks within the `execute` block of a workflow definition are evaluated
    class CogInputContext
      include SystemCogs::Call::InputContext
      include SystemCogs::Map::InputContext

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
    end
  end
end
