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
      class Provider
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
