# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            class Output < Agent::Output
              delegate :response, :session, to: :@invocation_result

              #: (ClaudeInvocation::Result) -> void
              def initialize(invocation_result)
                super()
                @invocation_result = invocation_result
              end
            end

            #: (Agent::Input) -> Agent::Output
            def invoke(input)
              invocation = ClaudeInvocation.new(@config, input)
              invocation.run!
              Output.new(invocation.result)
            end
          end
        end
      end
    end
  end
end
