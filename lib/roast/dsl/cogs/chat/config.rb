# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Config < Cog::Config
          PROVIDERS = {
            openai: {
              api_key_env_var: "OPENAI_API_KEY",
              base_url_env_var: "OPENAI_API_BASE",
              default_base_url: "https://api.openai.com/v1",
              default_model: "gpt-4o-mini",
            },
          }.freeze #: Hash[Symbol, Hash[Symbol, String]]

          # Configure the cog to use a specified API provider when invoking the llm
          #
          # #### See Also
          # - `use_default_provider!`
          #
          #: (Symbol) -> void
          def provider(provider)
            @values[:provider] = provider
          end

          # Configure the cog to use the default provider when invoking the llm
          #
          # The default LLM provider used by Roast is OpenAI (`:openai`).
          #
          # #### See Also
          # - `provider`
          #
          #: () -> void
          def use_default_provider!
            @values[:provider] = nil
          end

          # Get the validated provider name that the cog is configured to use when invoking the llm
          #
          # Note: this method will return the name of a valid provider or raise an `InvalidConfigError`.
          # It will __not__, however, validate that the you have access to the provider's API.
          # If you have not correctly configured API access, you will likely experience a failure when Roast attempts to
          # run your workflow.
          #
          # #### See Also
          # - `provider`
          # - `use_default_provider!`
          #
          #: () -> Symbol
          def valid_provider!
            provider = @values[:provider] || PROVIDERS.keys.first
            unless PROVIDERS.include?(provider)
              raise ArgumentError, "'#{provider}' is not a valid provider. Available providers include: #{PROVIDERS.keys.join(", ")}"
            end

            provider
          end

          # Configure the cog to use a specific API key when invoking the llm
          #
          # By default, the cog will use the value specified in a provider-specific environment variable, if present.
          #
          # #### See Also
          # - `use_api_key_from_environment!`
          #
          #: (String) -> void
          def api_key(key)
            @values[:api_key] = key
          end

          # Remove any explicit api key that the cog was configured to use when invoking the llm
          #
          # The cog will fall back to the value specified in a provider-specific environment variable, if present.
          #
          # #### Environment Variables
          # - OpenAI Provider: OPENAI_API_KEY
          #
          # #### See Also
          # - `api_key`
          #
          #: () -> void
          def use_api_key_from_environment!
            @values.delete(:api_key)
          end

          # Get the validated, configured value of the API key the cog is configured to use when invoking the llm
          #
          # This method will raise InvalidConfigError if no api key was provided, neither explicitly nor
          # via a provider-specific environment variable.
          #
          # #### Environment Variables
          # - OpenAI Provider: OPENAI_API_KEY
          #
          # #### See Also
          # - `api_key`
          # - `use_api_key_from_environment!`
          #
          #: () -> String
          def valid_api_key!
            value = @values.fetch(:api_key, ENV[PROVIDERS.dig(valid_provider!, :api_key_env_var).not_nil!])
            raise InvalidConfigError, "no api key provided" unless value

            value
          end

          # Configure the cog to use a specific API base URL when invoking the llm
          #
          # Default value:
          # - The value specified in provider-specific environment variable, if present;
          # - A provider-specific default, otherwise.
          #
          # #### See Also
          # - `use_default_base_url!`
          #
          #: (String) -> void
          def base_url(key)
            @values[:base_url] = key
          end

          # Remove any explicit API base URL that the cog was configured to use when invoking the llm
          #
          # The cog will fall back to a default value determined as follows:
          # - The value specified in provider-specific environment variable, if present;
          # - A provider-specific default, otherwise.
          #
          # #### Environment Variables
          # - OpenAI Provider: OPENAI_API_BASE
          #
          # #### See Also
          # - `base_url`
          #
          #: () -> void
          def use_default_base_url!
            @values[:base_url] = nil
          end

          # Get the validated, configured value of the API base URL the cog is configured to use when invoking the llm
          #
          # #### Environment Variables
          # - OpenAI Provider: OPENAI_API_BASE
          #
          # #### See Also
          # - `base_url`
          # - `use_default_base_url!`
          #
          #: () -> String
          def valid_base_url
            @values.fetch(:api_key, ENV[PROVIDERS.dig(valid_provider!, :base_url_env_var).not_nil!]) ||
              PROVIDERS.dig(valid_provider!, :default_base_url)
          end

          # Configure the cog to use a specific model when invoking the agent
          #
          # The model name format is provider-specific.
          #
          # #### See Also
          # - `use_default_model!`
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
          # Returns the provider's default model if no model was explicitly configured.
          #
          # #### See Also
          # - `model`
          # - `use_default_model!`
          #
          #: () -> String?
          def valid_model
            @values.fetch(:model, PROVIDERS.dig(valid_provider!, :default_model))
          end

          # Configure the cog to use a specific temperature when invoking the llm
          #
          # Temperature controls the randomness of the model's responses:
          # - Low (0.0-0.3): More deterministic and focused responses
          # - Medium (0.4-0.7): Balanced creativity and coherence
          # - High (0.8-1.0): More creative and varied responses
          #
          # #### See Also
          # - `use_default_temperature!`
          #
          #: (Float) -> void
          def temperature(value)
            if value < 0.0 || value > 1.0
              raise ArgumentError, "temperature must be between 0.0 and 1.0, got #{value}"
            end

            @values[:temperature] = value.to_f
          end

          # Remove any explicit temperature configuration
          #
          # The cog will fall back to the provider's default temperature.
          #
          # #### See Also
          # - `temperature`
          #
          #: () -> void
          def use_default_temperature!
            @values.delete(:temperature)
          end

          # Get the validated, configured temperature value
          #
          # Returns `nil` if no temperature was explicitly configured,
          # which means the provider will use its default.
          #
          # #### See Also
          # - `temperature`
          # - `use_default_temperature!`
          #
          #: () -> Float?
          def valid_temperature
            @values[:temperature]
          end

          # Configure the cog to verify that the model exists on the provider before attempting to invoke it
          #
          # Disabled by default.
          #
          # #### See Also
          # - `no_verify_model_exists!`
          # - `assume_model_exists!`
          # - `verify_model_exists?`
          #
          #: () -> void
          def verify_model_exists!
            @values[:verify_model_exists] = true
          end

          # Configure the cog __not__ to verify that the model exists on the provider before attempting to invoke it
          #
          # This is the default behaviour.
          #
          # #### See Also
          # - `verify_model_exists!`
          # - `assume_model_exists!`
          # - `verify_model_exists?`
          #
          #: () -> void
          def no_verify_model_exists!
            @values[:verify_model_exists] = false
          end

          # Check if the cog is configured to verify that the model exists on the provider
          #
          # #### See Also
          # - `verify_model_exists!`
          # - `no_verify_model_exists!`
          # - `assume_model_exists!`
          # - `verify_model_exists?`
          #
          #: () -> bool
          def verify_model_exists?
            @values.fetch(:verify_model_exists, false)
          end

          # Configure the cog to display the prompt when invoking the llm
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

          # Configure the cog __not__ to display the prompt when invoking the llm
          #
          # This is the default behaviour.
          #
          # #### See Also
          # - `show_prompt!`
          # - `show_prompt?`
          # - `no_display!`
          # - `quiet!`
          #
          #: () -> void
          def no_show_prompt!
            @values[:show_prompt] = false
          end

          # Check if the cog is configured to display the prompt when invoking the llm
          #
          # #### See Also
          # - `show_prompt!`
          # - `no_show_prompt!`
          #
          #: () -> bool
          def show_prompt?
            @values.fetch(:show_prompt, false)
          end

          # Configure the cog to display the llm's final response
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

          # Configure the cog __not__ to display the llm's final response
          #
          # #### See Also
          # - `show_response!`
          # - `show_response?`
          # - `no_display!`
          # - `quiet!`
          #
          #: () -> void
          def no_show_response!
            @values[:show_response] = false
          end

          # Check if the cog is configured to display the llm's final response
          #
          # #### See Also
          # - `show_response!`
          # - `no_show_response!`
          #
          #: () -> bool
          def show_response?
            @values.fetch(:show_response, true)
          end

          # Configure the cog to display statistics about the llm's operation
          #
          # Enabled by default.
          #
          # #### See Also
          # - `no_show_stats!`
          # - `show_stats?`
          # - `display!`
          #
          #: () -> void
          def show_stats!
            @values[:show_stats] = true
          end

          # Configure the cog __not__ to display statistics about the llm's operation
          #
          # #### See Also
          # - `show_stats!`
          # - `show_stats?`
          # - `no_display!`
          # - `quiet!`
          #
          #: () -> void
          def no_show_stats!
            @values[:show_stats] = false
          end

          # Check if the cog is configured to display statistics about the llm's operation
          #
          # #### See Also
          # - `show_stats!`
          # - `no_show_stats!`
          #
          #: () -> bool
          def show_stats?
            @values.fetch(:show_stats, true)
          end

          # Configure the cog to display all llm output
          #
          # This enables `show_prompt!`, `show_response!`, and `show_stats!`.
          #
          # #### See Also
          # - `no_display!`
          # - `quiet!`
          # - `show_prompt!`
          # - `show_response!`
          # - `show_stats!`
          #
          #: () -> void
          def display!
            show_prompt!
            show_response!
            show_stats!
          end

          # Configure the cog to __hide__ all llm output
          #
          # This enables `no_show_prompt!`, `no_show_response!`, and `no_show_stats!`.
          #
          # #### Alias Methods
          # - `no_display!`
          # - `quiet!`
          #
          # #### See Also
          # - `display!`
          # - `quiet!`
          # - `no_show_prompt!`
          # - `no_show_response!`
          # - `no_show_stats!`
          #
          #: () -> void
          def no_display!
            no_show_prompt!
            no_show_response!
            no_show_stats!
          end

          # Check if the cog is configured to display any output while running
          #
          # #### See Also
          # - `display!`
          # - `no_display!`
          # - `show_prompt?`
          # - `show_response?`
          # - `show_stats?`
          #
          #: () -> bool
          def display?
            show_prompt? || show_response? || show_stats?
          end

          alias_method(:quiet!, :no_display!)
          alias_method(:assume_model_exists!, :no_verify_model_exists!)
        end
      end
    end
  end
end
