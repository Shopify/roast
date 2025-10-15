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
          def initialize
            super
            @prompt = nil #: String?
          end

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
          #: String
          attr_reader :response

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end
        end

        class Config < Cog::Config
          #: (?String?) -> String?
          def api_key(key = nil)
            @values[:api_key] ||= key || ENV["OPENAI_API_KEY"]
          end

          #: (?String?) -> String?
          def base_url(url = nil)
            @values[:base_url] ||= url || ENV["OPENAI_API_BASE_URL"]
          end

          #: (?String?) -> String?
          def model(model_name = nil)
            @values[:model] ||= model_name
          end

          #: (?Symbol?) -> Symbol?
          def provider(provider_name = nil)
            @values[:provider] ||= provider_name
          end

          #: (?bool?) -> bool?
          def assume_model_exists(assume_model_exists = nil)
            @values[:assume_model_exists] ||= assume_model_exists || false
          end
        end

        #: () -> Roast::DSL::Cogs::Chat::Config
        def config # rubocop:disable Style/TrivialAccessors
          @config #: as Roast::DSL::Cogs::Chat::Config
        end

        #: (Input) -> Output
        def execute(input)
          chat = context.chat(
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

        def context
          @context ||= RubyLLM.context do |context|
            context.openai_api_key = config.api_key
            context.openai_api_base = config.base_url
          end
        end
      end
    end
  end
end
