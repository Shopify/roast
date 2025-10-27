# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Call < SystemCog
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

          # Integer
          attr_accessor :index

          #: () -> void
          def initialize
            super
            @index = 0
          end

          #: () -> void
          def validate!
            # raise a validation error if value is nil and coercion has not been run, to allow coercion to proceed
            raise Cog::Input::InvalidInputError, "'value' is required" if value.nil? && !permit_nil_value?
          end

          def coerce(input_return_value)
            # Do not raise a validation error if value is nil when validation is called *after* coercion.
            @permit_nil_value = true
            @value = input_return_value unless @value.present?
          end

          private

          #: () -> bool
          def permit_nil_value?
            @permit_nil_value ||= false
          end
        end

        class Output < Cog::Output
          #: (ExecutionManager) -> void
          def initialize(execution_manager)
            super()
            @execution_manager = execution_manager
          end
        end

        # @requires_ancestor: ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Call
          def create_call_system_cog(params, input_proc)
            SystemCogs::Call.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              em = ExecutionManager.new(@cog_registry, @config_manager, @all_execution_procs, params.run, input.value, input.index)
              em.prepare!
              em.run!

              Output.new(em)
            end
          end
        end

        # @requires_ancestor: CogInputContext
        module InputContext
          # @rbs [T] (Roast::DSL::SystemCogs::Call::Output) {() -> T} -> T
          #    | (Roast::DSL::SystemCogs::Call::Output) -> untyped
          def from(call_cog_output, &block)
            em = call_cog_output.instance_variable_get(:@execution_manager)
            raise CogInputContext::ContextNotFoundError if em.nil?

            return em.cog_input_context.instance_exec(&block) if block_given?

            em.send(:final_output)
          end
        end
      end
    end
  end
end
