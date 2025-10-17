# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext
      #: (?Symbol?) {() [self: Roast::DSL::Cogs::Cmd::Config] -> void} -> void
      def cmd(name = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cogs::Chat::Config] -> void} -> void
      def chat(name = nil, &block); end

      #: (?Symbol?) {() [self: Roast::DSL::Cog::Config] -> void} -> void
      def execute(name = nil, &block); end
    end
  end
end
