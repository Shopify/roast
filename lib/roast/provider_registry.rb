# typed: true
# frozen_string_literal: true

module Roast
  # Maintains the list of registered agent providers
  # Built in providers are registered automatically.
  # Custom agents are registered per workflow with `use`.)
  class ProviderRegistry
    class ProviderRegistryError < Roast::Error; end
    class DuplicateProviderNameError < ProviderRegistryError; end
    class ProviderNotFoundError < ProviderRegistryError; end

    #: Symbol
    attr_accessor :default

    def initialize
      @providers = {} #: Hash[Symbol, singleton(Cogs::Agent::Provider)]
    end

    #: (singleton(Cogs::Agent::Provider), ?Symbol?) -> void
    def register(provider_class, name = nil)
      name = build_provider_name(provider_class) if name.blank?
      raise DuplicateProviderNameError if exists?(name)

      @providers[name] = provider_class
    end

    #: (Symbol) -> singleton(Roast::Cogs::Agent::Provider)
    def fetch(name)
      name = default if name.nil?
      raise ProviderNotFoundError unless exists?(name)

      @providers.fetch(name)
    end

    #: -> void
    def prepare!
      register_builtin_providers
      @default = :claude
    end

    #: (Symbol) -> bool
    def exists?(name)
      @providers.key?(name)
    end

    private

    #: (singleton(Cogs::Agent::Provider)) -> Symbol
    def build_provider_name(provider_class)
      provider_class.name.not_nil!.demodulize.underscore.to_sym
    end

    def register_builtin_providers
      register(Cogs::Agent::Providers::Claude, :claude)
    end
  end
end
