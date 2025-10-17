# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext
      # TODO: I can't think of a good way to explicitly type the `scope_input` parameter
      #   (second parameter in the blocks for the cog methods defined here)

      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input, ?untyped) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | untyped)} -> void
      def cmd(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Chat::Input, ?untyped) [self: Roast::DSL::CogInputContext] -> (String | untyped)} -> void
      def chat(name = nil, &block); end

      # TODO: the return value of the block needs to include untyped because we don't want to
      #   force you to return a conforming value, if the last line of your input block is `my.foo = something`.
      #   Is there any value to the user in specifying the union of the useful return values with untyped?
      #   Should we define an overload signature instead of a redundant union?
      #: (?Symbol?) {(Roast::DSL::SystemCogs::Execute::Input, ?untyped) [self: Roast::DSL::CogInputContext] -> (Symbol | Array[untyped] | untyped )} -> void
      def execute(name = nil, &block); end

      #: (?Symbol?, ?Symbol?) {(Roast::DSL::SystemCogs::Map::Input, ?untyped) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def map(name = nil, map_executor_scope = nil, &block); end
    end
  end
end
