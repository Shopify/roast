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

    delegate :key?, to: :@providers

    def initialize
      @providers = {} #: Hash[Symbol, singleton(Cogs::Agent::Provider)]
      @default = ENV["ROAST_DEFAULT_AGENT"]&.to_sym || :claude
    end

    #: (singleton(Cogs::Agent::Provider), ?Symbol?) -> void
    def register(provider_class, name = nil)
      name = build_provider_name(provider_class) if name.blank?
      raise DuplicateProviderNameError if @providers.key?(name)

      @providers[name] = provider_class
    end

    def fetch(name)
      name = default if name.nil?
      raise ProviderNotFoundError unless @providers.key?(name)

      @providers.fetch(name)
    end

    private

    #: (singleton(Cogs::Agent::Provider)) -> Symbol
    def build_provider_name(provider_class)
      provider_class.name.not_nil!.demodulize.underscore.to_sym
    end
  end
end
