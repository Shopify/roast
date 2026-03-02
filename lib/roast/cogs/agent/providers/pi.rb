# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class Output < Agent::Output
            delegate :response, :session, :stats, to: :@invocation_result

            #: (PiInvocation::Result) -> void
            def initialize(invocation_result)
              super()
              @invocation_result = invocation_result
            end
          end

          #: (Agent::Input) -> Agent::Output
          def invoke(input)
            invocation = PiInvocation.new(@config, input)
            invocation.run!
            Output.new(invocation.result)
          end
        end
      end
    end
  end
end
