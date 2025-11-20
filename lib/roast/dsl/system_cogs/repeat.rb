# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Repeat < SystemCog
        class Config < Cog::Config; end

        class Params < SystemCog::Params
          #: Symbol
          attr_accessor :run

          #: (?Symbol?, run: Symbol) -> void
          def initialize(name = nil, run:)
            super(name)
            @run = run
          end
        end

        class Input < Cog::Input
          #: untyped
          attr_accessor :value

          #: Integer
          attr_accessor :max_iterations

          #: () -> void
          def initialize
            super
            @max_iterations = 100 # Default max iterations to prevent infinite loops
          end

          #: () -> void
          def validate!
            # value is optional for repeat
          end

          #: (untyped) -> void
          def coerce(input_return_value)
            super
            @value = input_return_value unless @value.present?
          end
        end

        class Output < Cog::Output
          #: (Array[ExecutionManager], Integer, bool) -> void
          def initialize(execution_managers, iterations, broke)
            super()
            @execution_managers = execution_managers
            @iterations = iterations
            @broke = broke
          end

          #: Integer
          attr_reader :iterations

          #: () -> bool
          def broke?
            @broke
          end
        end

        # @requires_ancestor: Roast::DSL::ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Repeat
          def create_repeat_system_cog(params, input_proc)
            SystemCogs::Repeat.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              execution_managers = []
              iteration = 0
              broke = T.let(false, T::Boolean)

              loop do
                iteration += 1
                break if iteration > input.max_iterations

                begin
                  em = ExecutionManager.new(
                    @cog_registry,
                    @config_manager,
                    @all_execution_procs,
                    scope: params.run,
                    scope_value: input.value,
                    scope_index: iteration - 1,
                  )
                  em.prepare!
                  em.run!

                  execution_managers << em
                rescue ControlFlow::BreakLoop
                  # Still add the execution manager even if we break
                  execution_managers << em
                  broke = true
                  break
                end
              end

              Output.new(execution_managers, execution_managers.length, broke)
            end
          end
        end

        # @requires_ancestor: Roast::DSL::CogInputContext
        module InputContext
          # @rbs [T] (Roast::DSL::SystemCogs::Repeat::Output) {() -> T} -> Array[T]
          #    | (Roast::DSL::SystemCogs::Repeat::Output) -> Array[untyped]
          def collect(repeat_cog_output, &block)
            ems = repeat_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            return ems.map { |em| em.cog_input_context.instance_exec(&block) } if block_given?

            ems.map do |em|
              last_cog = em.instance_variable_get(:@cog_stack).last
              raise CogInputManager::CogDoesNotExistError, "no cogs defined in scope" unless last_cog

              last_cog.output
            end
          end

          #: [A] (Roast::DSL::SystemCogs::Repeat::Output, ?A?) {(A?) -> A} -> A?
          def reduce(repeat_cog_output, initial_value = nil, &block)
            ems = repeat_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            accumulator = initial_value
            ems.each do |em|
              new_accumulator = em.cog_input_context.instance_exec(accumulator, &block) unless em.nil?
              case new_accumulator
              when nil
                # do not overwrite a non-nil value in the accumulator with a nil value,
                # even if one is returned from the block
              else
                accumulator = new_accumulator #: as A
              end
            end

            accumulator
          end
        end
      end
    end
  end
end
