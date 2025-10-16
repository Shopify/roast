# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Registry
        class CogRegistryError < Roast::Error; end
        class CouldNotDeriveCogNameError < CogRegistryError; end

        #: () -> Hash[Symbol, singleton(Cog)]
        def cogs
          # Hard-coded for now; these cogs are available for workflows
          [
            Cogs::Cmd,
            Cogs::Chat,
            Cogs::Execute,
          ].to_h do |cog_class|
            cog_class_name = cog_class.name
            raise CouldNotDeriveCogNameError if cog_class_name.nil?

            [cog_class_name.demodulize.underscore.to_sym, cog_class]
          end
        end
      end
    end
  end
end
