# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      # Chat cog for pure LLM interaction
      #
      # The chat cog provides pure LLM interaction without local system access. While it
      # cannot access local files or run local tools, it can still perform complex reasoning and
      # access any cloud-based tools and MCP servers according to the capabilities of the model and
      # the capabilities that may be provided to it by the LLM provider.
      #
      # Key characteristics:
      # - No access to local filesystem (cannot read or write local files)
      # - Cannot run local tools or commands
      # - Can access cloud-based tools and MCP servers provided by the LLM provider
      # - Performs request-response interactions
      # - Does not currently maintain conversation state across invocations (not yet implemented)
      # - Does not currently support automatic session resumption (not yet implemented)
      #
      # For tasks requiring local filesystem access or locally-configured tools, use the `agent` cog instead.
      class Chat < Cog
        # The configuration object for this chat cog instance
        #
        #: Roast::DSL::Cogs::Chat::Config
        attr_reader :config

        # Execute the chat completion with the given input and return the output
        #
        # Sends the input prompt to the configured LLM provider and returns the generated response.
        # Optionally displays the user prompt, LLM response, and basic statistics to the console
        # based on the cog's configuration.
        #
        # The execution is a simple request-response interaction without conversation history
        # or tool use capabilities.
        #
        #: (Input) -> Output
        def execute(input)
          chat = ruby_llm_context.chat(
            model: config.valid_model,
            provider: config.valid_provider!,
            assume_model_exists: !config.verify_model_exists?,
          )

          chat = chat.with_temperature(config.valid_temperature) if config.valid_temperature

          resp = chat.ask(input.prompt)
          chat.messages.each do |message|
            case message.role
            when :user
              puts "[USER PROMPT] #{message.content}" if config.show_prompt?
            when :assistant
              puts "[LLM RESPONSE] #{message.content}" if config.show_response?
            else
              # No other message types are expected, but let's show them if they do appear
              # but only the user has requested some form of output
              puts "[UNKNOWN] #{message.content}" if config.show_prompt? || config.show_response?
            end
          end
          if config.show_stats?
            puts "[LLM STATS]"
            puts "\tModel: #{resp.model_id}"
            puts "\tRole: #{resp.role}"
            puts "\tInput Tokens: #{resp.input_tokens}"
            puts "\tOutput Tokens: #{resp.output_tokens}"
          end

          Output.new(resp.content)
        end

        private

        # Get a RubyLLM context configured for this chat cog
        #
        #: () -> RubyLLM::Context
        def ruby_llm_context
          @ruby_llm_context ||= RubyLLM.context do |context|
            context.openai_api_key = config.valid_api_key!
            context.openai_api_base = config.valid_base_url
          end
        end
      end
    end
  end
end
