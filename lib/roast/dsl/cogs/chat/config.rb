# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Config < Cog::Config
          field :model, "gpt-4o-mini"
          field :api_key, ENV["OPENAI_API_KEY"]
          field :base_url, ENV.fetch("OPENAI_API_BASE_URL", "https://api.openai.com/v1")
          field :provider, :openai
          field :assume_model_exists, false

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
          # - `show_prompt?`
          # - `show_response?`
          # - `show_stats?`
          #
          #: () -> bool
          def display?
            show_prompt? || show_response? || show_stats?
          end

          alias_method(:quiet!, :no_display!)
        end
      end
    end
  end
end
