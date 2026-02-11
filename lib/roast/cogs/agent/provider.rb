# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      # Abstract base class for agent provider implementations
      #
      # Providers are responsible for interfacing with specific agent backends (e.g., Claude)
      # to execute agent requests. Each provider must implement the `invoke` method to handle
      # agent execution according to their specific API requirements.
      #
      # Subclasses should override `invoke` to provide concrete implementations that communicate
      # with their respective agent services.
      #
      # Provider also serves as the registry for available providers. Built-in providers are
      # lazily registered on first access. External gems can register additional providers:
      #
      #   Roast::Cogs::Agent::Provider.register(:my_agent, MyGem::MyAgentProvider)
      #
      class Provider
        class << self
          # Register a provider class under a symbolic name
          #
          #: (Symbol, singleton(Provider), ?default: bool) -> void
          def register(name, provider_class, default: false)
            ensure_initialized!
            registry[name] = provider_class
            @default_provider_name = name if default
          end

          # Return the provider class registered under the given name, or nil
          #
          #: (Symbol) -> singleton(Provider)?
          def resolve(name)
            ensure_initialized!
            registry[name]
          end

          # Check whether a provider is registered under the given name
          #
          #: (Symbol) -> bool
          def registered?(name)
            ensure_initialized!
            registry.key?(name)
          end

          # Return all registered provider names
          #
          #: () -> Array[Symbol]
          def registered_provider_names
            ensure_initialized!
            registry.keys
          end

          # Return the name of the default provider
          #
          # The default is either the provider explicitly marked with `default: true`,
          # or the first provider registered.
          #
          #: () -> Symbol?
          def default_provider_name
            ensure_initialized!
            @default_provider_name || registry.keys.first
          end

          private

          #: () -> Hash[Symbol, singleton(Provider)]
          def registry
            @registry ||= {}
          end

          # Ensure built-in providers are registered on first registry access
          #
          # References the built-in provider class to trigger Zeitwerk autoload on first
          # load, then explicitly registers it. The explicit registration is necessary
          # because Zeitwerk only executes the class body once — subsequent calls (e.g.,
          # after reset_registry! in tests) need the fallback.
          #
          #: () -> void
          def ensure_initialized!
            return if @initialized

            @initialized = true
            register(:claude, Providers::Claude, default: true)
          end
        end

        # Initialize a new provider with the given configuration
        #
        # Stores the agent configuration for use during invocation. The configuration contains
        # all settings needed to communicate with the agent service, such as API keys, model
        # names, and execution parameters.
        #
        # #### See Also
        # - `invoke`
        #
        #: (Config) -> void
        def initialize(config)
          super()
          @config = config
        end

        # Execute an agent request and return the result
        #
        # This method must be implemented by subclasses to handle the actual agent execution.
        # Implementations should use the stored configuration to set up the request, send the
        # input to the agent service, and return a properly formatted output.
        #
        # Raises `NotImplementedError` if called on the base Provider class.
        #
        # #### See Also
        # - `initialize`
        #
        #: (Input) -> Output
        def invoke(input)
          raise NotImplementedError, "Subclasses must implement #invoke"
        end
      end
    end
  end
end
