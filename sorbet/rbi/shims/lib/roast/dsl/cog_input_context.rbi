# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class CogInputContext
      #: (Symbol) -> Roast::DSL::Cog::Output
      def call(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Cmd::Output
      def cmd(name); end

      #: (Symbol) -> Roast::DSL::Cogs::Chat::Output
      def chat(name); end
    end
  end
end
