# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        class AgentCogError < Roast::Error; end
        class UnknownProviderError < AgentCogError; end
        class MissingProviderError < AgentCogError; end
        class MissingPromptError < AgentCogError; end

        class Config < Cog::Config
          VALID_PROVIDERS = [:claude].freeze #: Array[Symbol]

          # Configure the cog to use a specified provider when invoking an agent
          #
          # The provider is the source of the agent tool itself.
          # If no provider is specified, Anthropic Claude Code (`:claude`) will be used as the default provider.
          #
          # A provider must be properly installed on your system in order for Roast to be able to use it.
          #
          # #### See Also
          # - `use_default_provider!`
          # - `valid_provider!`
          #
          #: (Symbol) -> void
          def provider(provider)
            @values[:provider] = provider
          end

          # Configure the cog to use the default provider when invoking an agent
          #
          # The default provider used by Roast is Anthropic Claude Code (`:claude`).
          #
          # The provider must be properly installed on your system in order for Roast to be able to use it.
          #
          # #### See Also
          # - `provider`
          # - `valid_provider!`
          #
          #: () -> void
          def use_default_provider!
            @values[:provider] = nil
          end

          # Get the validated provider name that the cog is configured to use when invoking an agent
          #
          # Note: this method will return the name of a valid provider or raise an `InvalidConfigError`.
          # It will __not__, however, validate that the agent is properly installed on your system.
          # If the agent is not properly installed, you will likely experience a failure when Roast attempts to
          # run your workflow.
          #
          # #### See Also
          # - `provider`
          # - `use_default_provider!`
          #
          #: () -> Symbol
          def valid_provider!
            provider = @values[:provider] || VALID_PROVIDERS.first
            unless VALID_PROVIDERS.include?(provider)
              raise ArgumentError, "'#{provider}' is not a valid provider. Available providers include: #{VALID_PROVIDERS.join(", ")}"
            end

            provider
          end

          # Configure the cog to use a specific model when invoking the agent
          #
          # The model name format is provider-specific.
          #
          # #### See Also
          # - `use_default_model!`
          # - `valid_model`
          #
          #: (String) -> void
          def model(model)
            @values[:model] = model
          end

          # Configure the cog to use the provider's default model when invoking the agent
          #
          # Note: the default model will be different for different providers.
          #
          # #### See Also
          # - `model`
          #
          #: () -> void
          def use_default_model!
            @values[:model] = nil
          end

          # Get the validated, configured value of the model the cog is configured to use when running the agent
          #
          # `nil` means that the provider should use its own default model, however that is configured.
          #
          #: () -> String?
          def valid_model
            @values[:model].presence
          end

          # Configure the cog with an initial prompt component that will be appended to the agent's system prompt
          # every time the agent is invoked
          #
          # #### See Also
          # - `no_initial_prompt!`
          # - `valid_initial_prompt`
          #
          #: (String) -> void
          def initial_prompt(prompt)
            @values[:initial_prompt] = prompt
          end

          # Configure the cog __not__ to append an initial prompt to the agent's system prompt when the agent is invoked
          #
          # #### See Also
          # - `initial_prompt`
          # - `valid_initial_prompt`
          #
          #: () -> void
          def no_initial_prompt!
            @values[:initial_prompt] = ""
          end

          # Get the validated, configured initial prompt that will be appended to the agent's system prompt when
          # the agent is invoked
          #
          # This value will be `nil` if __no__ prompt should be appended.
          #
          # #### See Also
          # - `initial_prompt`
          # - `no_initial_prompt!`
          #
          #: () -> String?
          def valid_initial_prompt
            @values[:initial_prompt].presence
          end

          # Configure the cog to apply the default set of system and user permissions when running the agent
          #
          # How these permissions are defined and configured is specific to the agent provider being used.
          #
          # The cog's default behaviour is to run with __no__ permissions.
          #
          # #### Alias Methods
          # - `apply_permissions!`
          # - `no_skip_permissions!`
          #
          # #### Inverse Methods
          # - `no_apply_permissions!`
          # - `skip_permissions!`
          #
          #: () -> void
          def apply_permissions!
            @values[:apply_permissions] = true
          end

          # Configure the cog to run the agent with __no__ permissions applied
          #
          # The cog's default behaviour is to run with __no__ permissions.
          #
          # #### Alias Methods
          # - `no_apply_permissions!`
          # - `skip_permissions!`
          #
          # #### Inverse Methods
          # - `apply_permissions!`
          # - `no_skip_permissions!`
          #
          #: () -> void
          def no_apply_permissions!
            @values[:apply_permissions] = false
          end

          # Check if the cog is configured to apply permissions when running the agent
          #
          # #### See Also
          # - `apply_permissions!`
          # - `no_apply_permissions!`
          # - `skip_permissions!`
          # - `no_skip_permissions!`
          #
          #: () -> bool
          def apply_permissions?
            !!@values[:apply_permissions]
          end

          # Configure the cog to display the prompt when running the agent
          #
          # Disabled by default.
          #
          # #### See Also
          # - `no_show_prompt!`
          # - `show_prompt?`
          # - `display!`
          #
          #: () -> void
          def show_prompt!
            @values[:show_prompt] = true
          end

          # Configure the cog __not__ to display the prompt when running the agent
          #
          # This is the default behaviour.
          #
          # #### See Also
          # - `show_prompt!`
          # - `show_prompt?`
          # - `no_display!`
          #
          #: () -> void
          def no_show_prompt!
            @values[:show_prompt] = false
          end

          # Check if the cog is configured to display the prompt when running the agent
          #
          # #### See Also
          # - `show_prompt!`
          # - `no_show_prompt!`
          #
          #: () -> bool
          def show_prompt?
            @values.fetch(:show_prompt, false)
          end

          # Configure the cog to display the agent's in-progress messages when running
          #
          # This includes thinking blocks and other intermediate output from the agent.
          # Enabled by default.
          #
          # #### See Also
          # - `no_show_progress!`
          # - `show_progress?`
          # - `display!`
          #
          #: () -> void
          def show_progress!
            @values[:show_progress] = true
          end

          # Configure the cog __not__ to display the agent's in-progress messages when running
          #
          # This will hide thinking blocks and other intermediate output from the agent.
          #
          # #### See Also
          # - `show_progress!`
          # - `show_progress?`
          # - `no_display!`
          #
          #: () -> void
          def no_show_progress!
            @values[:show_progress] = false
          end

          # Check if the cog is configured to display the agent's in-progress messages when running
          #
          # #### See Also
          # - `show_progress!`
          # - `no_show_progress!`
          #
          #: () -> bool
          def show_progress?
            @values.fetch(:show_progress, true)
          end

          # Configure the cog to display the agent's final response
          #
          # Enabled by default.
          #
          # #### See Also
          # - `no_show_response!`
          # - `show_response?`
          # - `display!`
          #
          #: () -> void
          def show_response!
            @values[:show_response] = true
          end

          # Configure the cog __not__ to display the agent's final response
          #
          # #### See Also
          # - `show_response!`
          # - `show_response?`
          # - `no_display!`
          #
          #: () -> void
          def no_show_response!
            @values[:show_response] = false
          end

          # Check if the cog is configured to display the agent's final response
          #
          # #### See Also
          # - `show_response!`
          # - `no_show_response!`
          #
          #: () -> bool
          def show_response?
            @values.fetch(:show_response, true)
          end

          # Configure the cog to display all agent output
          #
          # This enables `show_prompt!`, `show_progress!`, and `show_response!`.
          #
          # #### See Also
          # - `no_display!`
          # - `show_prompt!`
          # - `show_progress!`
          # - `show_response!`
          #
          #: () -> void
          def display!
            show_prompt!
            show_progress!
            show_response!
          end

          # Configure the cog to __hide__ all agent output
          #
          # This enables `no_show_prompt!`, `no_show_progress!`, and `no_show_response!`.
          #
          # #### Alias Methods
          # - `no_display!`
          # - `quiet!`
          #
          # #### See Also
          # - `display!`
          # - `no_show_prompt!`
          # - `no_show_progress!`
          # - `no_show_response!`
          #
          #: () -> void
          def no_display!
            no_show_prompt!
            no_show_progress!
            no_show_response!
          end

          # Check if the cog is configured to display any output while running
          #
          # #### See Also
          # - `show_prompt?`
          # - `show_progress?`
          # - `show_response?`
          #
          #: () -> bool
          def display?
            show_prompt? || show_progress? || show_response?
          end

          alias_method(:skip_permissions!, :no_apply_permissions!)
          alias_method(:no_skip_permissions!, :apply_permissions!)
          alias_method(:quiet!, :no_display!)
        end

        class Input < Cog::Input
          #: String?
          attr_accessor :prompt

          #: () -> void
          def initialize
            super
            @prompt = nil #: String?
          end

          #: () -> void
          def validate!
            valid_prompt!
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt ||= input_return_value
            end
          end

          #: () -> String
          def valid_prompt!
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless @prompt.present?

            @prompt
          end
        end

        class Output < Cog::Output
          #: String
          attr_reader :response
        end

        #: Agent::Config
        attr_reader :config

        #: (Input) -> Output
        def execute(input)
          puts "[USER PROMPT] #{input.valid_prompt!}" if config.show_prompt?
          output = provider.invoke(input)
          puts "[AGENT RESPONSE] #{output.response}" if config.show_response?
          output
        end

        private

        #: () -> Provider
        def provider
          @provider ||= case config.valid_provider!
          when :claude
            Providers::Claude.new(config)
          else
            raise UnknownProviderError, "Unknown provider: #{config.valid_provider!}"
          end
        end
      end
    end
  end
end
