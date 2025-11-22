# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Registry for managing available cogs in a workflow
      class Registry
        # Parent class for all cog registry errors
        class CogRegistryError < Roast::Error; end

        # Raised when a cog name cannot be derived from a cog class
        class CouldNotDeriveCogNameError < CogRegistryError; end

        # Initialize a new cog registry with standard cogs
        #
        # Automatically registers all system cogs and standard cogs provided by core Roast.
        #
        # #### See Also
        # - `use`
        # - `cogs`
        #
        def initialize
          @cogs = {}
          use(SystemCogs::Call)
          use(SystemCogs::Map)
          use(SystemCogs::Repeat)
          use(Cogs::Cmd)
          use(Cogs::Chat)
          use(Cogs::Agent)
          use(Cogs::Ruby)
        end

        # Hash mapping cog names to cog classes
        #
        # #### See Also
        # - `use`
        #
        #: Hash[Symbol, singleton(Cog)]
        attr_reader :cogs

        # Register a cog class for use in workflows
        #
        # Adds the provided cog class to the registry, deriving its name from the class name.
        # The cog name is the underscored, demodulized version of the class name
        # (e.g., `Roast::DSL::Cogs::MyCustomCog` becomes `:my_custom_cog`).
        #
        # Raises `CouldNotDeriveCogNameError` if the cog class name cannot be determined.
        #
        # #### See Also
        # - `cogs`
        #
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
