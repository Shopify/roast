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
            provider: config.provider,
            assume_model_exists: config.assume_model_exists,
          )

          resp = chat.ask(input.prompt)
          puts "Model: #{resp.model_id}"
          puts "Role: #{resp.role}"
          puts "Input Tokens: #{resp.input_tokens}"
          puts "Output Tokens: #{resp.output_tokens}"

          chat.messages.each do |message|
            puts "[#{message.role.to_s.upcase}] #{message.content}"
          end

          Output.new(resp.content)
        end

        #: () -> RubyLLM::Context
        def ruby_llm_context
          @ruby_llm_context ||= RubyLLM.context do |context|
            context.openai_api_key = config.api_key unless config.api_key.nil?
            context.openai_api_base = config.base_url unless config.base_url.nil?
          end
        end
      end
    end
  end
end
