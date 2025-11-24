# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      # Map cog for executing a scope over a collection of items
      #
      # Executes a named execution scope (defined with `execute(:name)`) for each item in a collection.
      # Supports both serial and parallel execution modes. Each iteration receives the current item
      # as its value and the iteration index.
      class Map < SystemCog
        # Parent class for all `map` cog output access errors
        class MapOutputAccessError < Roast::Error; end

        # Raised when attempting to access an iteration that did not run
        #
        # This can occur when a `break!` is called during iteration, preventing
        # subsequent iterations from executing.
        class MapIterationDidNotRunError < MapOutputAccessError; end

        # Configuration for the `map` cog
        class Config < Cog::Config
          # Configure the cog to execute iterations in parallel with a maximum number of concurrent tasks
          #
          # Pass `0` to enable unlimited parallelism (no concurrency limit).
          # Pass a positive integer to limit the number of iterations that can run concurrently.
          #
          # Default: serial execution (equivalent to `parallel(1)`)
          #
          # #### See Also
          # - `parallel!`
          # - `no_parallel!`
          #
          #: (Integer) -> void
          def parallel(value)
            # treat 0 as unlimited parallelism
            @values[:parallel] = value > 0 ? value : nil
          end

          # Configure the cog to execute iterations in parallel with unlimited concurrency
          #
          # This removes any limit on the number of iterations that can run concurrently.
          # All iterations will start simultaneously.
          #
          # #### See Also
          # - `parallel`
          # - `no_parallel!`
          #
          #: () -> void
          def parallel!
            @values[:parallel] = nil
          end

          # Configure the cog to execute iterations serially (one at a time)
          #
          # This is the default behavior. Iterations will run sequentially in order.
          #
          # #### See Also
          # - `parallel`
          # - `parallel!`
          #
          #: () -> void
          def no_parallel!
            @values[:parallel] = 1
          end

          # Validate the configuration
          #
          #: () -> void
          def validate!
            valid_parallel!
          end

          # Get the validated, configured parallelism limit
          #
          # Returns `nil` for unlimited parallelism, or an `Integer` for the maximum number
          # of concurrent iterations. This method will raise an `InvalidConfigError` if the
          # parallelism value is negative.
          #
          # #### See Also
          # - `parallel`
          # - `parallel!`
          # - `no_parallel!`
          #
          #: () -> Integer?
          def valid_parallel!
            parallel = @values.fetch(:parallel, 1)
            return if parallel.nil?
            raise InvalidConfigError, "'parallel' must be >= 0 if specified" if parallel < 0

            parallel
          end
        end

        # Parameters for the `map` cog
        class Params < SystemCog::Params
          # The name of the execution scope to invoke for each item
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

        # Input for the `map` cog
        #
        # Provides the collection of items to iterate over and an optional starting index.
        # Each item will be passed to the execution scope along with its index.
        class Input < Cog::Input
          # The collection of items to iterate over
          #
          # This can be any enumerable collection. Each item will be passed as the value
          # to the execution scope. Required.
          #
          #: Array[untyped]
          attr_accessor :items

          # The starting index for the first iteration
          #
          # Defaults to `0`. This affects the index value passed to each iteration but does
          # not change which items are processed.
          #
          #: Integer
          attr_accessor :initial_index

          # Initialize the input with default values
          #
          #: () -> void
          def initialize
            super
            @items = []
            @initial_index = 0
          end

          # Validate that required input values are present
          #
          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'items' is required" if items.nil?
            raise Cog::Input::InvalidInputError if items.empty? && !coerce_ran?
          end

          # Coerce the input from the return value of the input block
          #
          # Sets the items from the input block's return value if not already set directly.
          # Converts enumerable objects to arrays and wraps non-enumerable single values in an array.
          #
          #: (Array[untyped]) -> void
          def coerce(input_return_value)
            super
            return if @items.present?

            @items = input_return_value.respond_to?(:each) ? input_return_value.to_a : Array.wrap(input_return_value)
          end
        end

        # Output from running the `map` cog
        #
        # Contains results from each iteration, allowing access to individual iteration outputs.
        # Iterations that did not run (due to `break!`) will be `nil`.
        #
        # #### See Also
        # - `Roast::DSL::CogInputContext#collect` - retrieves all iteration outputs as an array
        # - `Roast::DSL::CogInputContext#reduce` - reduces iteration outputs to a single value
        class Output < Cog::Output
          # Initialize the output with results for each iteration
          #
          #: (Array[ExecutionManager?]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
          end

          # Check if a specific iteration ran successfully
          #
          # Returns `true` if the iteration at the given index executed, `false` if it was
          # skipped (e.g., due to `break!`). Supports negative indices to count from the end.
          #
          # #### See Also
          # - `iteration`
          #
          #: (Integer) -> bool
          def iteration?(index)
            @execution_managers.fetch(index).present?
          end

          # Get the output from a specific iteration, in concert with `from`
          #
          # Returns a `Roast::DSL::SystemCogs::Call::Output` object for the iteration at the given index.
          # Supports negative indices to count from the end (e.g., `-1` for the last iteration).
          # Raises `MapIterationDidNotRunError` if the iteration did not run.
          #
          # Use `from` on the return value of this method, as for a single `call` cog invocation, to access the
          # final output and individual cog outputs from the specified invocation.
          #
          # #### Usage
          # ```ruby
          # # Access a specific iteration
          # result = from(map!(:process_items).iteration(2))
          #
          # # Access with negative index
          # result = from(map!(:process_items).iteration(-1))
          # ```
          #
          # #### See Also
          # - `iteration?`
          # - `first`
          # - `last`
          # - `Roast::DSL::CogInputContext#from`
          #
          #: (Integer) -> Call::Output
          def iteration(index)
            em = @execution_managers.fetch(index)
            raise MapIterationDidNotRunError, index unless em.present?

            Call::Output.new(em)
          end

          # Get the output from the first iteration
          #
          # Convenience method equivalent to `iteration(0)`. Raises `MapIterationDidNotRunError`
          # if the first iteration did not run.
          #
          # #### See Also
          # - `iteration`
          # - `last`
          #
          #: () -> Call::Output
          def first
            iteration(0)
          end

          # Get the output from the last iteration that ran
          #
          # Convenience method equivalent to `iteration(-1)`. Raises `MapIterationDidNotRunError`
          # if the last iteration did not run.
          #
          # #### See Also
          # - `iteration`
          # - `first`
          #
          #: () -> Call::Output
          def last
            iteration(-1)
          end
        end

        # @requires_ancestor: Roast::DSL::ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Map
          def create_map_system_cog(params, input_proc)
            SystemCogs::Map.new(params.name, input_proc) do |input, config|
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              input = input #: as Input
              config = config #: as Config
              max_parallel_tasks = config.valid_parallel!
              if max_parallel_tasks == 1
                execute_map_in_series(params.run, input)
              else
                execute_map_in_parallel(params.run, input, max_parallel_tasks)
              end
            end
          end

          #: (Symbol, untyped, Integer) -> ExecutionManager
          def create_execution_manager_for_map_item(scope, scope_value, scope_index)
            ExecutionManager.new(
              @cog_registry,
              @config_manager,
              @all_execution_procs,
              @workflow_context,
              scope:,
              scope_value:,
              scope_index:,
            )
          end

          #: (Symbol, Map::Input) -> Output
          def execute_map_in_series(run, input)
            ems = []
            input.items.each_with_index do |item, index|
              ems << em = create_execution_manager_for_map_item(run, item, index + input.initial_index)
              em.prepare!
              em.run!
            rescue ControlFlow::Break
              # TODO: do something with the message passed to break!
              break
            end
            ems.fill(nil, ems.length, input.items.length - ems.length)
            Output.new(ems)
          end

          #: (Symbol, Map::Input, Integer?) -> Output
          def execute_map_in_parallel(run, input, max_parallel_tasks)
            barrier = Async::Barrier.new
            semaphore = Async::Semaphore.new(max_parallel_tasks, parent: barrier) if max_parallel_tasks.present?
            ems = {}
            input.items.map.with_index do |item, index|
              (semaphore || barrier).async(finished: false) do |task|
                task.annotate("Map Invocation #{index + input.initial_index}")
                ems[index] = em = create_execution_manager_for_map_item(run, item, index + input.initial_index)
                em.prepare!
                em.run!
              end
            end #: Array[Async::Task]

            # Wait on the tasks in their completion order, so that an exception in a task will be raised as soon as it occurs
            # noinspection RubyArgCount
            barrier.wait do |task|
              task.wait
            rescue ControlFlow::Break
              # TODO: do something with the message passed to break!
              barrier.stop
            rescue StandardError => e
              barrier.stop
              raise e
            end

            Output.new((0...input.items.length).map { |idx| ems[idx] })
          ensure
            # noinspection RubyRedundantSafeNavigation
            barrier&.stop
          end
        end

        # @requires_ancestor: Roast::DSL::CogInputContext
        module InputContext
          # Collect the results from all `map` cog iterations into an array
          #
          # Extracts the final output from each iteration that ran. When called without a block,
          # returns an array of the final outputs directly. When called with a block, executes
          # the block in the context of each iteration's input context, receiving the final output,
          # the original item value, and the iteration index as arguments.
          #
          # Iterations that did not run (due to `break!`) will be represented as `nil` in the
          # returned array.
          #
          # #### Usage
          # ```ruby
          # # Get all final outputs directly
          # results = collect(map!(:process_items))
          #
          # # Transform each output with access to the original item and index
          # results = collect(map!(:process_items)) do |output, item, index|
          #   { item: item, result: output, position: index }
          # end
          #
          # # Access other cog outputs from within each iteration
          # results = collect(map!(:process_items)) do |output, item, index|
          #   inner_cog!(:some_step)
          # end
          # ```
          #
          # #### See Also
          # - `reduce`
          # - `Roast::DSL::SystemCogs::Map::Output`
          #
          # @rbs [T] (Roast::DSL::SystemCogs::Map::Output) {() -> T} -> Array[T]
          #    | (Roast::DSL::SystemCogs::Map::Output) -> Array[untyped]
          def collect(map_cog_output, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            return ems.map do |em|
              next unless em

              scope_value = em.instance_variable_get(:@scope_value)
              scope_index = em.instance_variable_get(:@scope_index)
              final_output = em.final_output
              em.cog_input_context.instance_exec(final_output, scope_value, scope_index, &block)
            end if block_given?

            ems.map { |em| em&.final_output }
          end

          # Reduce the results from all `map` cog iterations to a single value
          #
          # Processes each iteration's output sequentially, combining them into an accumulator value.
          # The block receives the current accumulator value, the final output from the iteration,
          # the original item value, and the iteration index. The block should return the new
          # accumulator value.
          #
          # If the block returns `nil`, the accumulator will __not__ be updated (preserving any
          # previous non-nil value). This prevents accidental overwrites with `nil` values.
          #
          # Iterations that did not run (due to `break!`) are skipped.
          #
          # #### Usage
          # ```ruby
          # # Sum all outputs
          # total = reduce(map!(:calculate_scores), 0) do |sum, output, item, index|
          #   sum + output
          # end
          #
          # # Build a hash from outputs
          # results = reduce(map!(:process_items), {}) do |hash, output, item, index|
          #   hash.merge(item => output)
          # end
          #
          # # Collect with conditional accumulation
          # valid_results = reduce(map!(:validate_items), []) do |acc, output, item, index|
          #   output.valid? ? acc + [output] : acc
          # end
          # ```
          #
          # #### See Also
          # - `collect`
          # - `Roast::DSL::SystemCogs::Map::Output`
          #
          #: [A] (Roast::DSL::SystemCogs::Map::Output, ?A?) {(A?, untyped) -> A} -> A?
          def reduce(map_cog_output, initial_value = nil, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            accumulator = initial_value
            ems.compact.each do |em|
              next unless em

              scope_value = em.instance_variable_get(:@scope_value)
              scope_index = em.instance_variable_get(:@scope_index)
              final_output = em.final_output
              new_accumulator = em.cog_input_context.instance_exec(accumulator, final_output, scope_value, scope_index, &block)
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
