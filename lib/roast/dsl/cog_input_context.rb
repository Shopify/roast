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

      #: () -> void
      def skip!
        raise ControlFlow::SkipCog
      end

      #: () -> void
      def fail!
        raise ControlFlow::FailCog
      end
    end
  end
end
