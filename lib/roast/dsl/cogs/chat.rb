# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        class Input < Cog::Input
          #: String?
          attr_accessor :prompt

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'prompt' is required" unless prompt.present?
          end

          #: (untyped) -> void
          def coerce!(input_return_value)
            if input_return_value.is_a?(String)
              self.prompt = input_return_value
            end
          end
        end

        class Output < Cog::Output
          #: String
          attr_reader :response

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end
        end

        class Config < Cog::Config
          #: () -> String?
          def openai_api_key
            @values[:openai_api_key] ||= ENV["OPENAI_API_KEY"]
          end

          #: () -> String?
          def openai_api_base_url
            @values[:openai_api_base_url] ||= ENV["OPENAI_API_BASE_URL"]
          end
        end

        #: (Input) -> Output
        def execute(input)
          config = @config #: as Config
          RubyLLM.configure do |ruby_llm_config|
            ruby_llm_config.openai_api_key = config.openai_api_key
            ruby_llm_config.openai_api_base = config.openai_api_base_url
          end

          chat = RubyLLM.chat
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
      end
    end
  end
end
