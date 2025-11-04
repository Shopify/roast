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
        end

        class Input < Cog::Input
          #: String?
          attr_accessor :prompt

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless prompt.present?
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt = input_return_value
            end
          end
        end

        class Output < Cog::Output
          include Cog::Output::WithJson

          #: String
          attr_reader :response

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end

          private

          def json_text
            response
          end
        end

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
