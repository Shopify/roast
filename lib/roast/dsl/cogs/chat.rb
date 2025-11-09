# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        #: Roast::DSL::Cogs::Chat::Config
        attr_reader :config

        #: (Input) -> Output
        def execute(input)
          chat = ruby_llm_context.chat(
            model: config.model,
            provider: config.valid_provider!,
            assume_model_exists: config.assume_model_exists,
          )

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
