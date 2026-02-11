# frozen_string_literal: true

require "test_helper"

module Roast
  module SystemCogs
    class MapTest < ActiveSupport::TestCase
      def setup
        @registry = Cog::Registry.new
        @registry.use(TestCogSupport::TestCog)

        @config_manager = ConfigManager.new(@registry, [])
        @config_manager.prepare!

        @workflow_context = WorkflowContext.new(
          params: WorkflowParams.new([], [], {}),
          tmpdir: Dir.tmpdir,
          workflow_dir: Pathname.new(Dir.tmpdir),
        )
      end

      def build_manager(execution_procs, scope: nil, scope_value: nil, scope_index: 0)
        ExecutionManager.new(
          @registry,
          @config_manager,
          execution_procs,
          @workflow_context,
          scope: scope,
          scope_value: scope_value,
          scope_index: scope_index,
        )
      end

      test "Config parallel sets concurrency limit" do
        config = Map::Config.new
        config.parallel(4)

        assert_equal 4, config.valid_parallel!
      end

      test "Config parallel with 0 sets unlimited parallelism" do
        config = Map::Config.new
        config.parallel(0)

        assert_nil config.valid_parallel!
      end

      test "Config parallel! sets unlimited parallelism" do
        config = Map::Config.new
        config.parallel!

        assert_nil config.valid_parallel!
      end

      test "Config no_parallel! sets serial execution" do
        config = Map::Config.new
        config.parallel!
        config.no_parallel!

        assert_equal 1, config.valid_parallel!
      end

      test "Config defaults to serial execution" do
        config = Map::Config.new

        assert_equal 1, config.valid_parallel!
      end

      test "Config validate! raises on negative parallel value" do
        config = Map::Config.new
        config.instance_variable_get(:@values)[:parallel] = -1

        assert_raises(Cog::Config::InvalidConfigError) do
          config.validate!
        end
      end

      test "Input validate! passes when items are set" do
        input = Map::Input.new
        input.items = ["a", "b"]

        assert_nothing_raised { input.validate! }
      end

      test "Input validate! raises when items are empty and coerce has not run" do
        input = Map::Input.new

        assert_raises(Cog::Input::InvalidInputError) do
          input.validate!
        end
      end

      test "Input validate! passes when items are empty after coerce" do
        input = Map::Input.new
        input.coerce([])

        assert_nothing_raised { input.validate! }
      end

      test "Input coerce sets items from array" do
        input = Map::Input.new
        input.coerce(["a", "b", "c"])

        assert_equal ["a", "b", "c"], input.items
      end

      test "Input coerce wraps non-enumerable value in array" do
        input = Map::Input.new
        input.coerce("single")

        assert_equal ["single"], input.items
      end

      test "Input coerce converts enumerable to array" do
        input = Map::Input.new
        input.coerce(1..3)

        assert_equal [1, 2, 3], input.items
      end

      test "Input coerce does not overwrite items if already set" do
        input = Map::Input.new
        input.items = ["original"]
        input.coerce(["overwritten"])

        assert_equal ["original"], input.items
      end

      test "Input initial_index defaults to 0" do
        input = Map::Input.new

        assert_equal 0, input.initial_index
      end

      test "Output iteration? returns true for a run iteration" do
        em = mock("execution_manager")
        output = Map::Output.new([em])

        assert output.iteration?(0)
      end

      test "Output iteration? returns false for a nil iteration" do
        output = Map::Output.new([nil])

        refute output.iteration?(0)
      end

      test "Output iteration returns Call::Output for valid index" do
        em = mock("execution_manager")
        output = Map::Output.new([em])

        result = output.iteration(0)
        assert_instance_of Call::Output, result
      end

      test "Output iteration raises MapIterationDidNotRunError for nil iteration" do
        output = Map::Output.new([nil])

        assert_raises(Map::MapIterationDidNotRunError) do
          output.iteration(0)
        end
      end

      test "Output iteration supports negative indices" do
        em = mock("execution_manager")
        output = Map::Output.new([nil, em])

        result = output.iteration(-1)
        assert_instance_of Call::Output, result
      end

      test "Output first returns first iteration" do
        em = mock("execution_manager")
        output = Map::Output.new([em, nil])

        result = output.first
        assert_instance_of Call::Output, result
      end

      test "Output last returns last iteration" do
        em = mock("execution_manager")
        output = Map::Output.new([nil, em])

        result = output.last
        assert_instance_of Call::Output, result
      end

      test "map executes scope for each item in series" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :process_item) do |input|
              input.items = ["a", "b", "c"]
            end
            outputs { collect(map(:my_map)) }
          }],
          process_item: [proc {
            test_cog(:step) { |_input, scope, _index| scope }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "a", results[0].value
        assert_equal "b", results[1].value
        assert_equal "c", results[2].value
      end

      test "map passes correct indices to each iteration" do
        received_indices = []
        exec_procs = {
          nil => [proc {
            map(run: :indexed) do |input|
              input.items = ["x", "y"]
              input.initial_index = 5
            end
          }],
          indexed: [proc {
            test_cog(:step) do |_input, _scope, index|
              received_indices << index
              "done"
            end
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal [5, 6], received_indices
      end

      test "map handles ControlFlow::Next by skipping iteration and continuing" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :with_next) do |input|
              input.items = ["a", "b", "c"]
            end
            outputs { collect(map(:my_map)) }
          }],
          with_next: [proc {
            test_cog(:step) do |_input, scope, _index|
              raise ControlFlow::Next if scope == "b"

              scope
            end
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "a", results[0].value
        assert_nil results[1]
        assert_equal "c", results[2].value
      end

      test "map handles ControlFlow::Break by stopping iteration" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :with_break) do |input|
              input.items = ["a", "b", "c"]
            end
            outputs { collect(map(:my_map)) }
          }],
          with_break: [proc {
            test_cog(:step) do |_input, scope, _index|
              raise ControlFlow::Break if scope == "b"

              scope
            end
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "a", results[0].value
        assert_nil results[1]
        assert_nil results[2]
      end

      test "collect returns final outputs from all iterations" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :collect_test) { ["x", "y", "z"] }
            outputs { collect(map(:my_map)) }
          }],
          collect_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope.upcase }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "X", results[0].value
        assert_equal "Y", results[1].value
        assert_equal "Z", results[2].value
      end

      test "collect with block transforms each iteration output" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :transform_test) { ["hello", "world"] }
            outputs { collect(map(:my_map)) { |output, item, index| "#{index}:#{item}=#{output.value}" } }
          }],
          transform_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope.upcase }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal ["0:hello=HELLO", "1:world=WORLD"], manager.final_output
      end

      test "reduce accumulates values across iterations" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :reduce_test) { [1, 2, 3] }
            outputs { reduce(map(:my_map), 0) { |sum, output, _item, _index| sum + output.value } }
          }],
          reduce_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope * 10 }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal 60, manager.final_output
      end

      test "reduce does not overwrite accumulator with nil" do
        exec_procs = {
          nil => [proc {
            map(:my_map, run: :nil_reduce) { ["a", "b"] }
            outputs { reduce(map(:my_map), "initial") { |_acc, _output, _item, _index| nil } }
          }],
          nil_reduce: [proc {
            test_cog(:step) { |_input, scope, _index| scope }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "initial", manager.final_output
      end

      test "map executes in parallel when configured" do
        config_proc = proc { map { parallel! } }
        config_manager = ConfigManager.new(@registry, [config_proc])
        config_manager.prepare!

        exec_procs = {
          nil => [proc {
            map(:my_map, run: :parallel_test) { ["a", "b", "c"] }
            outputs { collect(map(:my_map)) }
          }],
          parallel_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope.upcase }
          }],
        }
        manager = ExecutionManager.new(
          @registry, config_manager, exec_procs, @workflow_context
        )
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "A", results[0].value
        assert_equal "B", results[1].value
        assert_equal "C", results[2].value
      end
    end
  end
end
