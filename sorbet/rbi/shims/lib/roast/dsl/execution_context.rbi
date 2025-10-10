# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext
      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | nil)} -> void
      def cmd(name = nil, &block); end
    end
  end
end
