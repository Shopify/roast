# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext
      #: (Symbol, ?Symbol?) ?{(Roast::DSL::SystemCogs::Call::Input, untyped) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def call(scope, name = nil, &block); end

      #: (Symbol, ?Symbol?) {(Roast::DSL::SystemCogs::Map::Input, untyped) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def map(scope, name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input, untyped) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | void)} -> void
      def cmd(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Chat::Input, untyped) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def chat(name = nil, &block); end
    end
  end
end
