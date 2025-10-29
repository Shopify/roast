# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ExecutionContext

      ########################################
      #       Special Context Methods
      ########################################

      #: () {() [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def outputs(&block); end

      ########################################
      #             System Cogs
      ########################################

      #: (?Symbol?, run: Symbol) ?{(Roast::DSL::SystemCogs::Call::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def call(name = nil, run:,  &block); end

      #: (?Symbol?, run: Symbol) {(Roast::DSL::SystemCogs::Map::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def map(name = nil, run:, &block); end

      ########################################
      #            Standard Cogs
      ########################################

      #: (?Symbol?) {(Roast::DSL::Cogs::Agent::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def agent(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Chat::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | void)} -> void
      def chat(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Cmd::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> (String | Array[String] | void)} -> void
      def cmd(name = nil, &block); end

      #: (?Symbol?) {(Roast::DSL::Cogs::Ruby::Input, untyped, Integer) [self: Roast::DSL::CogInputContext] -> untyped} -> void
      def ruby(name = nil, &block); end
    end
  end
end
