# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      # Repeat cog for executing a scope multiple times in a loop
      #
      # Executes a named execution scope (defined with `execute(:name)`) repeatedly until
      # a `break!` is called. The output from each iteration becomes the input value for
      # the next iteration, allowing for iterative transformations.
      class Repeat < SystemCog
        # Configuration for the `repeat` cog
        #
        # Currently has no configuration options.
        class Config < Cog::Config; end

        # Parameters for the `repeat` cog
        class Params < SystemCog::Params
          # The name of the execution scope to invoke for each iteration
          #
          #: Symbol
          attr_accessor :run

          # Initialize parameters with the cog name and execution scope
          #
          #: (?Symbol?, run: Symbol) -> void
          def initialize(name = nil, run:)
            super(name)
            @run = run
          end
        end

        # Input for the `repeat` cog
        #
        # Provides the initial value to pass to the first iteration. Each subsequent iteration
        # receives the output from the previous iteration as its value.
        class Input < Cog::Input
          # The initial value to pass to the first iteration
          #
          # This value will be passed to the execution scope on the first iteration. Subsequent
          # iterations receive the output from the previous iteration. Required.
          #
          #: untyped
          attr_accessor :value

          # The starting index for the first iteration
          #
          # Defaults to `0`. This affects the index value passed to each iteration.
          #
          # Integer
          attr_accessor :index

          # The maximum number of iterations for which the loop may run
          #
          # Defaults to `nil`, meaning that no maximum iteration limit is applied
          #
          #: Integer?
          attr_accessor :max_iterations

          # Initialize the input with default values
          #
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
            raise Cog::Input::InvalidInputError, "'max_iterations' must be >= 1 if present" if (max_iterations || 1) < 1
          end

          # Coerce the input from the return value of the input block
          #
          # Sets the value from the input block's return value if not already set directly.
          #
          #: (untyped) -> void
          def coerce(input_return_value)
            super
            @value = input_return_value unless @value.present?
          end
        end

        # Output from running the `repeat` cog
        #
        # Contains results from all iterations that ran. Provides access to the final value
        # (output from the last iteration) as well as individual iteration results.
        #
        # #### See Also
        # - `Roast::DSL::CogInputContext#collect` - retrieves all iteration outputs as an array (via `results`)
        # - `Roast::DSL::CogInputContext#reduce` - reduces iteration outputs to a single value (via `results`)
        class Output < Cog::Output
          # Initialize the output with results for all iterations
          #
          #: (Array[ExecutionManager]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
          end

          # Get the final output value from the last iteration
          #
          # This is the output from the last iteration before `break!` was called.
          # Returns `nil` if no iterations ran.
          #
          # #### Usage
          # ```ruby
          # # Get the final result directly
          # final = repeat!(:process)
          # ```
          #
          # #### See Also
          # - `last`
          # - `results`
          #
          #: () -> untyped
          def value
            @execution_managers.last&.final_output
          end

          # Get the output from a specific iteration
          #
          # Returns a `Roast::DSL::SystemCogs::Call::Output` object for the iteration at the given index.
          # Supports negative indices to count from the end (e.g., `-1` for the last iteration).
          #
          # #### Usage
          # ```ruby
          # # Access a specific iteration
          # result = from(repeat!(:process).iteration(2))
          #
          # # Access with negative index
          # result = from(repeat!(:process).iteration(-1))
          # ```
          #
          # #### See Also
          # - `first`
          # - `last`
          # - `value`
          # - `Roast::DSL::CogInputContext#from`
          #
          #: (Integer) -> Call::Output
          def iteration(index)
            Call::Output.new(@execution_managers.fetch(index))
          end

          # Get the output from the first iteration
          #
          # Convenience method equivalent to `iteration(0)`.
          #
          # #### See Also
          # - `iteration`
          # - `last`
          #
          #: () -> Call::Output
          def first
            iteration(0)
          end

          # Get the output from the last iteration
          #
          # Convenience method equivalent to `iteration(-1)`. Returns the same value as
          # calling `value`, but wrapped in a `Roast::DSL::SystemCogs::Call::Output` for use with `from`.
          #
          # #### See Also
          # - `iteration`
          # - `first`
          # - `value`
          #
          #: () -> Call::Output
          def last
            iteration(-1)
          end

          # Get all iteration results as a `Roast::DSL::SystemCogs::Map::Output` object
          #
          # Returns a `Roast::DSL::SystemCogs::Map::Output` containing all iterations, which can be used with
          # `collect` or `reduce` to process all iteration outputs.
          #
          # #### Usage
          # ```ruby
          # # Collect all iteration outputs
          # all_results = collect(repeat!(:process).results)
          #
          # # Reduce all iteration outputs
          # sum = reduce(repeat!(:process).results, 0) { |acc, output| acc + output }
          # ```
          #
          # #### See Also
          # - `value`
          # - `Roast::DSL::CogInputContext#collect`
          # - `Roast::DSL::CogInputContext#reduce`
          # - `Roast::DSL::SystemCogs::Map::Output`
          #
          #: () -> Map::Output
          def results
            Map::Output.new(@execution_managers)
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

              ems = [] #: Array[ExecutionManager]
              scope_value = input.value.deep_dup
              max_iterations = input.max_iterations
              loop do
                ems << em = ExecutionManager.new(
                  @cog_registry,
                  @config_manager,
                  @all_execution_procs,
                  @workflow_context,
                  scope: params.run,
                  scope_value: scope_value,
                  scope_index: ems.length,
                )
                em.prepare!
                em.run!
                scope_value = em.final_output
                break if max_iterations.present? && ems.length >= max_iterations
              rescue ControlFlow::Break
                # TODO: do something with the message passed to break!
                break
              end
              Output.new(ems)
            end
          end
        end
      end
    end
  end
end
