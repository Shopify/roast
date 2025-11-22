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

        #: Agent::Config
        attr_reader :config

        #: (Input) -> Output
        def execute(input)
          puts "[USER PROMPT] #{input.valid_prompt!}" if config.show_prompt?
          output = provider.invoke(input)
          # NOTE: If progress is displayed, the agent's response will always be the last progress message,
          # so showing it again is duplicative.
          puts "[AGENT RESPONSE] #{output.response}" if config.show_response? && !config.show_progress?
          puts "[AGENT STATS] #{output.stats}" if config.show_stats?
          puts "Session ID: #{output.session}" if config.show_stats?
          output
        end

        private

        #: () -> Provider
        def provider
          @provider ||= case config.valid_provider!
          when :claude
            Providers::Claude.new(config)
          else
            raise UnknownProviderError, "Unknown provider: #{config.valid_provider!}"
          end
        end
      end
    end
  end
end
