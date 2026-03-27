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
            invocations = [] #: Array[PiInvocation]
            input.prompts.each do |prompt|
              previous_session = invocations.last&.result&.session
              invocation = PiInvocation.new(
                @config,
                prompt,
                previous_session || input.session,
              )
              invocation.run!
              invocations << invocation
              break unless invocation.result.success
            end
            final_result = invocations.last.not_nil!.result
            final_result.stats = invocations.filter_map { |i| i.result.stats }.reduce(:+) if invocations.size > 1
            Output.new(final_result)
          end
        end
      end
    end
  end
end
