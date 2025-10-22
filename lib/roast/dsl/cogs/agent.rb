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
              self.prompt ||= input_return_value
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
          field :provider, :claude
        end

        #: Roast::DSL::Cogs::Agent::Config
        attr_reader :config

        #: (Input) -> Output
        def execute(input)
          prompt = input.prompt
          raise MissingPromptError, "Prompt is required for agent cog" unless prompt.present?

          provider_name = config.provider
          raise MissingProviderError, "Provider config is required for agent cog" unless provider_name.present?

          provider_instance = create_provider(provider_name)
          response = provider_instance.invoke(prompt)
          puts "[AGENT RESPONSE] #{response}"
          Output.new(response)
        end

        private

        #: (Symbol) -> Roast::DSL::Cogs::Agent::Providers::Base
        def create_provider(provider_name)
          case provider_name
          when :claude
            Providers::Claude.new
          else
            raise UnknownProviderError, "Unknown provider: #{provider_name}"
          end
        end
      end
    end
  end
end
