# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext
      #: (?Symbol?) {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def call(name = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def map(name = nil, &block); end

      #: (?(Symbol | Regexp)?) {() [self: Roast::DSL::Cogs::Cmd::Config] -> void} -> void
      def cmd(name_or_pattern = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cogs::Chat::Config] -> void} -> void
      def chat(name = nil, &block); end
    end
  end
end
