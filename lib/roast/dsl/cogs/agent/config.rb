# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
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

          # Configure the cog to use a specific base command when invoking the agent
          #
          # The command format is provider-specific.
          #
          # #### See Also
          # - `use_default_command!`
          #
          #: (String | Array[String]) -> void
          def command(command)
            @values[:command] = command
          end

          # Configure the cog to use the provider's default command when invoking the agent
          #
          # Note: the default command will be different for different providers.
          #
          # #### See Also
          # - `command`
          #
          #: () -> void
          def use_default_command!
            @values[:command] = nil
          end

          # Get the validated, configured value of the command the cog is configured to use when running the agent
          #
          # Returns `nil` if the provider should use its own default command, however that is configured.
          #
          # #### See Also
          # - `command`
          # - `use_default_command!`
          #
          #: () -> (String | Array[String])?
          def valid_command
            @values[:command].presence
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
          # Returns `nil` if the provider should use its own default model, however that is configured.
          #
          # #### See Also
          # - `model`
          # - `use_default_model!`
          #
          #: () -> String?
          def valid_model
            @values[:model].presence
          end

          # Configure the cog with a custom system prompt that will completely replace the agent's
          # default system prompt every time the agent is invoked
          #
          # #### See Also
          # - `no_replace_system_prompt!`
          # - `append_system_prompt`
          #
          #: (String) -> void
          def replace_system_prompt(prompt)
            @values[:replace_system_prompt] = prompt
          end

          # Configure the cog __not__ to replace the agent's default system prompt
          #
          # This is the default behaviour.
          #
          # #### See Also
          # - `replace_system_prompt`
          #
          #: () -> void
          def no_replace_system_prompt!
            @values[:replace_system_prompt] = ""
          end

          # Get the validated, configured replacement system prompt
          #
          # Returns `nil` if the default system prompt should __not__ be replaced.
          #
          # #### See Also
          # - `replace_system_prompt`
          # - `no_replace_system_prompt!`
          #
          #: () -> String?
          def valid_replace_system_prompt
            @values[:replace_system_prompt].presence
          end

          # Configure the cog with a prompt component that will be appended to the agent's system prompt
          # every time the agent is invoked
          #
          # Use this to add custom instructions while preserving the provider's default system prompt.
          #
          # This can also be combined with with `replace_system_prompt`.
          #
          # #### See Also
          # - `no_append_system_prompt!`
          # - `replace_system_prompt`
          #
          #: (String) -> void
          def append_system_prompt(prompt)
            @values[:append_system_prompt] = prompt
          end

          # Configure the cog __not__ to append anything to the agent's system prompt when the agent is invoked
          #
          # This is the default behaviour.
          #
          # #### See Also
          # - `append_system_prompt`
          #
          #: () -> void
          def no_append_system_prompt!
            @values[:append_system_prompt] = ""
          end

          # Get the validated, configured prompt that will be appended to the agent's system prompt when
          # the agent is invoked
          #
          # Returns `nil` if __no__ prompt should be appended.
          #
          # #### See Also
          # - `append_system_prompt`
          # - `no_append_system_prompt!`
          #
          #: () -> String?
          def valid_append_system_prompt
            @values[:append_system_prompt].presence
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
          # - `quiet!`
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
          # - `quiet!`
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
          # - `quiet!`
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

          # Configure the cog to display statistics about the agent's operation
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

          # Configure the cog __not__ to display statistics about the agent's operation
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

          # Check if the cog is configured to display statistics about the agent's operation
          #
          # #### See Also
          # - `show_stats!`
          # - `no_show_stats!`
          #
          #: () -> bool
          def show_stats?
            @values.fetch(:show_stats, true)
          end

          # Configure the cog to display all agent output
          #
          # This enables `show_prompt!`, `show_progress!`, `show_response!`, and `show_stats!`.
          #
          # #### See Also
          # - `no_display!`
          # - `quiet!`
          # - `show_prompt!`
          # - `show_progress!`
          # - `show_response!`
          # - `show_stats!`
          #
          #: () -> void
          def display!
            show_prompt!
            show_progress!
            show_response!
            show_stats!
          end

          # Configure the cog to __hide__ all agent output
          #
          # This enables `no_show_prompt!`, `no_show_progress!`, `no_show_response!`, `no_show_stats!`.
          #
          # #### Alias Methods
          # - `no_display!`
          # - `quiet!`
          #
          # #### See Also
          # - `display!`
          # - `quiet!`
          # - `no_show_prompt!`
          # - `no_show_progress!`
          # - `no_show_response!`
          # - `no_show_stats!`
          #
          #: () -> void
          def no_display!
            no_show_prompt!
            no_show_progress!
            no_show_response!
            no_show_stats!
          end

          # Check if the cog is configured to display any output while running
          #
          # #### See Also
          # - `show_prompt?`
          # - `show_progress?`
          # - `show_response?`
          # - `show_stats?`
          #
          #: () -> bool
          def display?
            show_prompt? || show_progress? || show_response? || show_stats?
          end

          # Configure the cog to dump raw messages received from the agent process to a file
          #
          # This is intended for development and debugging purposes to inspect the raw message stream
          # from the agent provider.
          #
          #: (String) -> void
          def dump_raw_agent_messages_to(filename)
            @values[:dump_raw_agent_messages_to] = filename
          end

          # Get the validated, configured path to which raw agent messages should be dumped
          #
          # Returns `nil` if no path has been configured.
          #
          # This is intended for development and debugging purposes to inspect the raw message stream
          # from the agent provider.
          #
          # #### See Also
          # - `dump_raw_agent_messages_to`
          #
          #: () -> Pathname?
          def valid_dump_raw_agent_messages_to_path
            Pathname.new(@values[:dump_raw_agent_messages_to]) if @values[:dump_raw_agent_messages_to]
          end

          alias_method(:skip_permissions!, :no_apply_permissions!)
          alias_method(:no_skip_permissions!, :apply_permissions!)
          alias_method(:quiet!, :no_display!)
        end
      end
    end
  end
end
