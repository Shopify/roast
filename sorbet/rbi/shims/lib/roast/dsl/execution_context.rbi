# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext

      #: () {() [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def outputs(&block); end

      #: (?Symbol?, run: Symbol) ?{(Roast::DSL::SystemCogs::Call::Input, untyped) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def call(name = nil, run:,  &block); end

      #: (?Symbol?, run: Symbol) {(Roast::DSL::SystemCogs::Map::Input, untyped) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def map(name = nil, run:, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input, untyped) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | void)} -> void
      def cmd(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Chat::Input, untyped) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def chat(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Agent::Input, untyped) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def agent(name = nil, &block); end
    end
  end
end
