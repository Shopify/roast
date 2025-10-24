# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class CogInputContext

      #: [T] (Roast::DSL::SystemCogs::Call::Output) {() -> T} -> T
      #: (Roast::DSL::SystemCogs::Call::Output) -> untyped
      def from(call_cog_output, &block); end

      #: [T] (Roast::DSL::SystemCogs::Map::Output) {() -> T} -> Array[T]
      #: (Roast::DSL::SystemCogs::Map::Output) -> Array[untyped]
      def collect(map_cog_output, &block); end

      #: [A] (Roast::DSL::SystemCogs::Map::Output, ?NilClass) {(A?) -> A} -> A?
      #: [A] (Roast::DSL::SystemCogs::Map::Output, ?A) {(A) -> A} -> A
      def reduce(map_cog_output, initial_value = nil, &block); end

      #: (Symbol) -> Roast::DSL::SystemCogs::Call::Output?
      def call(name); end

      #: (Symbol) -> Roast::DSL::SystemCogs::Call::Output
      def call!(name); end

      #: (Symbol) -> bool
      def call?(name); end

      #: (Symbol) -> Roast::DSL::SystemCogs::Map::Output?
      def map(name); end

      #: (Symbol) -> Roast::DSL::SystemCogs::Map::Output
      def map!(name); end

      #: (Symbol) -> bool
      def map?(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Cmd::Output?
      def cmd(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Cmd::Output
      def cmd!(name); end

      #: (Symbol) -> bool
      def cmd?(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Chat::Output?
      def chat(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Chat::Output
      def chat!(name); end

      #: (Symbol) -> bool
      def chat?(name); end
    end
  end
end
