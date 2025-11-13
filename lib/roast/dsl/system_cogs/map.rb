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
            @items = Array.wrap(input_return_value) unless @items.present?
          end
        end

        class Output < Cog::Output
          #: (Array[ExecutionManager]) -> void
          def initialize(execution_managers)
            super()
            @execution_managers = execution_managers
          end
        end

        #: Config
        attr_accessor :config

        # @requires_ancestor: Roast::DSL::ExecutionManager
        module Manager
          private

          #: (Params, ^(Cog::Input) -> untyped) -> SystemCogs::Map
          def create_map_system_cog(params, input_proc)
            SystemCogs::Map.new(params.name, input_proc) do |input, config|
              input = input #: as Input
              config = config #: as Config
              raise ExecutionManager::ExecutionScopeNotSpecifiedError unless params.run.present?

              create_and_run_execution_manager = proc do |item, index|
                em = ExecutionManager.new(
                  @cog_registry,
                  @config_manager,
                  @all_execution_procs,
                  @workflow_context,
                  scope: params.run,
                  scope_value: item,
                  scope_index: index + input.initial_index,
                )
                em.prepare!
                em.run!
                em
              end

              max_parallel_tasks = config.valid_parallel!
              max_parallel_semaphore = Async::Semaphore.new(max_parallel_tasks) if max_parallel_tasks.present?
              tasks = input.items.map.with_index do |item, index|
                if max_parallel_semaphore
                  max_parallel_semaphore.async { create_and_run_execution_manager.call(item, index) }
                else
                  Async { create_and_run_execution_manager.call(item, index) }
                end
              end
              ems = tasks.map(&:wait)

              Output.new(ems)
            end
          end
        end

        # @requires_ancestor: Roast::DSL::CogInputContext
        module InputContext
          # @rbs [T] (Roast::DSL::SystemCogs::Map::Output) {() -> T} -> Array[T]
          #    | (Roast::DSL::SystemCogs::Map::Output) -> Array[untyped]
          def collect(map_cog_output, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
            raise CogInputContext::ContextNotFoundError if ems.nil?

            return ems.map { |em| em.cog_input_context.instance_exec(&block) } if block_given?

            ems.map do |em|
              last_cog = em.instance_variable_get(:@cog_stack).last
              raise CogInputManager::CogDoesNotExistError, "no cogs defined in scope" unless last_cog

              last_cog.output
            end
          end

          #: [A] (Roast::DSL::SystemCogs::Map::Output, ?A?) {(A?) -> A} -> A?
          def reduce(map_cog_output, initial_value = nil, &block)
            ems = map_cog_output.instance_variable_get(:@execution_managers)
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
