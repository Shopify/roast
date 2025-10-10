# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext
      #: (?Symbol?) {() [self: Roast::DSL::Cogs::Cmd] -> String} -> void
      def cmd(name = nil, &block); end
    end
  end
end
