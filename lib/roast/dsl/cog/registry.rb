# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Registry
        class CogRegistryError < Roast::Error; end
        class CouldNotDeriveCogNameError < CogRegistryError; end

        def initialize
          @cogs = {}
          use(SystemCogs::Call)
          use(SystemCogs::Map)
          use(Cogs::Cmd)
          use(Cogs::Chat)
          use(Cogs::Agent)
          use(Cogs::Ruby)
        end

        #: Hash[Symbol, singleton(Cog)]
        attr_reader :cogs

        #: (singleton(Roast::DSL::Cog)) -> void
        def use(cog_class)
          reg = create_registration(cog_class)
          cogs[reg.first] = reg.second
        end

        private

        #: (singleton(Roast::DSL::Cog)) -> Array(Symbol, singleton(Cog))
        def create_registration(cog_class)
          cog_class_name = cog_class.name
          raise CouldNotDeriveCogNameError if cog_class_name.nil?

          [cog_class_name.demodulize.underscore.to_sym, cog_class]
        end
      end
    end
  end
end
