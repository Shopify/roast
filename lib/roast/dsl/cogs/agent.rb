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
          field :provider, :claude do |provider|
            unless VALID_PROVIDERS.include?(provider)
              raise ArgumentError, "'#{provider}' is not a valid provider. Available providers include: #{VALID_PROVIDERS.join(", ")}"
            end

            provider
          end
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

          #: (String response) -> void
          def initialize(response)
            super()
            @response = response
          end
        end

        #: Agent::Config
        attr_reader :config

        #: (Input) -> Output
        def execute(input)
          response = provider.invoke(input.valid_prompt!)
          puts "[AGENT RESPONSE] #{response}"
          Output.new(response)
        end

        private

        #: () -> Providers::Base
        def provider
          @provider ||= case config.provider
          when :claude
            Providers::Claude.new
          else
            raise UnknownProviderError, "Unknown provider: #{config.provider}"
          end
        end
      end
    end
  end
end
