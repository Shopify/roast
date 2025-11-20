# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module SystemCogs
      class Map < SystemCog
        class Config < Cog::Config
          #: (Integer) -> void
          def parallel(value)
            # treat 0 as unlimited parallelism
            @values[:parallel] = value > 0 ? value : nil
          end

          #: () -> void
          def parallel!
            @values[:parallel] = nil
          end

          #: () -> void
          def no_parallel!
            @values[:parallel] = 1
          end

          #: () -> void
          def validate!
            valid_parallel!
          end

          #: () -> Integer?
          def valid_parallel!
            parallel = @values.fetch(:parallel, 1)
            return if parallel.nil?
            raise InvalidConfigError, "'parallel' must be >= 0 if specified" if parallel < 0

            parallel
          end
        end

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
          #: Array[untyped]
          attr_accessor :items

          #: Integer
          attr_accessor :initial_index

          def initialize
            super
            @items = []
            @initial_index = 0
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'items' is required" if items.nil?
            raise Cog::Input::InvalidInputError if items.empty? && !coerce_ran?
          end

          #: (Array[untyped]) -> void
          def coerce(input_return_value)
            super
            return if @items.present?

            @items = input_return_value.respond_to?(:each) ? input_return_value.to_a : Array.wrap(input_return_value)
          end
        end

        class Output < Cog::Output
          #: (Array[ExecutionManager?]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
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
          # @rbs [T] (Roast::DSL::SystemCogs::Map::Output) {() -> T} -> Array[T]
          #    | (Roast::DSL::SystemCogs::Map::Output) -> Array[untyped]
          def collect(map_cog_output, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            return ems.map do |em|
              next unless em

              scope_value = em.instance_variable_get(:@scope_value)
              scope_index = em.instance_variable_get(:@scope_index)
              final_output = em.send(:final_output)
              em.cog_input_context.instance_exec(final_output, scope_value, scope_index, &block)
            end if block_given?

            ems.map { |em| em&.send(:final_output) }
          end

          #: [A] (Roast::DSL::SystemCogs::Map::Output, ?A?) {(A?, untyped) -> A} -> A?
          def reduce(map_cog_output, initial_value = nil, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            accumulator = initial_value
            ems.compact.each do |em|
              next unless em

              scope_value = em.instance_variable_get(:@scope_value)
              scope_index = em.instance_variable_get(:@scope_index)
              final_output = em.send(:final_output)
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
