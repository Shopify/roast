# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class Output < Agent::Output
            delegate :response, :session, :stats, to: :@invocation_result

            #: (ClaudeInvocation::Result) -> void
            def initialize(invocation_result)
              super()
              @invocation_result = invocation_result
            end
          end

          #: (Agent::Input) -> Agent::Output
          def invoke(input)
            invocations = [] #: Array[ClaudeInvocation]
            input.prompts.each do |prompt|
              invocation = ClaudeInvocation.new(@config, prompt, invocations.last&.result&.session || input.session)
              invocation.run!
              invocations << invocation
              break unless invocation.result.success
            end
            Output.new(invocations.last.not_nil!.result)
          end
        end
      end
    end
  end
end
