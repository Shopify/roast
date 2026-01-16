# typed: true
# frozen_string_literal: true

module Roast
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

    #: (?String?) -> void
    def next!(message = nil)
      raise ControlFlow::Next, message
    end

    #: (?String?) -> void
    def break!(message = nil)
      raise ControlFlow::Break, message
    end
  end
end
