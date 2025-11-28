# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      # Call cog for invoking named execution scopes
      #
      # Executes a named execution scope (defined with `execute(:name)`) with a provided value
      # and index. The scope runs independently and can access the value and index through
      # special variables.
      class Call < SystemCog
        class Config < Cog::Config; end

        # Parameters for the call system cog
        class Params < SystemCog::Params
          # The name of the execution scope to invoke
          #
          #: Symbol
          attr_accessor :run

          #: (?Symbol?, run: Symbol) -> void
          def initialize(name = nil, run:)
            super(name)
            @run = run
          end
        end

        # Input for the call system cog
        #
        # Provides the value and index to be passed to the execution scope. The scope
        # can access these through the implicit variables available in the execution context.
        class Input < Cog::Input
          # The value to pass to the execution scope
          #
          # This value becomes available in the called scope and can be accessed by steps
          # within that scope. Required.
          #
          #: untyped
          attr_accessor :value

          # The index value to pass to the execution scope
          #
          # Defaults to 0. Can be used to track position when calling scopes in a sequence.
          #
          # Integer
          attr_accessor :index

          #: () -> void
          def initialize
            super
            @index = 0
          end

          # Validate that required input values are present
          #
          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'value' is required" if value.nil? && !coerce_ran?
          end

          # Coerce the input from the return value of the input block
          #
          # Sets the value from the input block's return value if not already set directly.
          #
          def coerce(input_return_value)
            super
            @value = input_return_value unless @value.present?
          end
        end

        # Output from running the `call` cog
        #
        # Contains the result from the called scope. Use the `from` method to retrieve
        # the final output from the scope's execution.
        #
        # #### See Also
        # - `Roast::DSL::CogInputContext#from` - retrieves output from a `call` cog
        class Output < Cog::Output
          #: (ExecutionManager) -> void
          def initialize(execution_manager)
            super()
            @execution_manager = execution_manager
          end
        end

        # @requires_ancestor: Roast::DSL::ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Call
          def create_call_system_cog(params, input_proc)
            SystemCogs::Call.new(params.name, input_proc) do |input|
              input = input #: as Input
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              em = ExecutionManager.new(
                @cog_registry,
                @config_manager,
                @all_execution_procs,
                @workflow_context,
                scope: params.run,
                scope_value: input.value,
                scope_index: input.index,
              )
              em.prepare!
              begin
                em.run!
              rescue ControlFlow::Break
                # treat `break!` like `next!` in a `call` invocation
                # TODO: maybe do something with the message passed to break!
              end
              Output.new(em)
            end
          end
        end

        # @requires_ancestor: Roast::DSL::CogInputContext
        module InputContext
          # Retrieve the output from a `call` cog's execution scope
          #
          # Extracts the final output from the execution scope that was invoked by the call cog.
          # When called without a block, returns the final output directly. When called with a block,
          # executes the block in the context of the called scope's input context, receiving the final
          # output as an argument.
          #
          # This allows you to access the results of a called scope and optionally transform them
          # and/or access other outputs from within that scope.
          #
          # #### Usage
          # ```ruby
          # # Get the final output directly
          # result = from(call!(:my_call))
          #
          # # Transform the output with a block
          # transformed = from(call!(:my_call)) { |output| output.upcase }
          #
          # # Access other cog outputs from within the called scope
          # inner_result = from(call!(:my_call)) { inner_cog!(:some_step) }
          # ```
          #
          # #### See Also
          # - `Roast::DSL::SystemCogs::Call::Output` - the output type from call cogs
          #
          # @rbs [T] (Roast::DSL::SystemCogs::Call::Output) {(untyped, untyped, Integer) -> T} -> T
          #    | (Roast::DSL::SystemCogs::Call::Output) -> untyped
          def from(call_cog_output, &block)
            em = call_cog_output.instance_variable_get(:@execution_manager)
            raise CogInputContext::ContextNotFoundError if em.nil?

            final_output = em.final_output
            scope_value = em.instance_variable_get(:@scope_value).deep_dup
            scope_index = em.instance_variable_get(:@scope_index)
            return em.cog_input_context.instance_exec(final_output, scope_value, scope_index, &block) if block_given?

            final_output
          end
        end
      end
    end
  end
end
