# frozen_string_literal: true

require "test_helper"

module Roast
  module SystemCogs
    class RepeatTest < ActiveSupport::TestCase
      def setup
        @registry = Cog::Registry.new
        @registry.use(TestCogSupport::TestCog)

        @workflow_context = WorkflowContext.new(
          params: WorkflowParams.new([], [], {}),
          tmpdir: Dir.tmpdir,
          workflow_dir: Pathname.new(Dir.tmpdir),
        )

        @config_manager = ConfigManager.new(@registry, [], @workflow_context)
        @config_manager.prepare!
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

      def build_bare_manager
        build_manager({ nil => [] })
      end

      def build_ran_manager(output_value)
        value = output_value
        exec_procs = {
          nil => [proc {
            test_cog(:step) { value }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!
        manager
      end

      test "Params stores run scope name" do
        params = Repeat::Params.new(:my_repeat, run: :loop_body)

        assert_equal :my_repeat, params.name
        assert_equal :loop_body, params.run
      end

      test "Params auto-generates name when not provided" do
        params = Repeat::Params.new(run: :loop_body)

        assert_kind_of Symbol, params.name
        assert_equal :loop_body, params.run
      end

      test "Input validate! passes when value is set" do
        input = Repeat::Input.new
        input.value = "hello"

        assert_nothing_raised { input.validate! }
      end

      test "Input validate! raises when value is nil and coerce has not run" do
        input = Repeat::Input.new

        assert_raises(Cog::Input::InvalidInputError) do
          input.validate!
        end
      end

      test "Input validate! passes when value is nil after coerce" do
        input = Repeat::Input.new
        input.coerce(nil)

        assert_nothing_raised { input.validate! }
      end

      test "Input index defaults to 0" do
        input = Repeat::Input.new

        assert_equal 0, input.index
      end

      test "Input max_iterations defaults to nil" do
        input = Repeat::Input.new

        assert_nil input.max_iterations
      end

      test "Input validate! raises when max_iterations is 0" do
        input = Repeat::Input.new
        input.value = "hello"
        input.max_iterations = 0

        assert_raises(Cog::Input::InvalidInputError) do
          input.validate!
        end
      end

      test "Input validate! raises when max_iterations is negative" do
        input = Repeat::Input.new
        input.value = "hello"
        input.max_iterations = -5

        assert_raises(Cog::Input::InvalidInputError) do
          input.validate!
        end
      end

      test "Input validate! passes when max_iterations is 1" do
        input = Repeat::Input.new
        input.value = "hello"
        input.max_iterations = 1

        assert_nothing_raised { input.validate! }
      end

      test "Input coerce sets value from return value" do
        input = Repeat::Input.new
        input.coerce("from_block")

        assert_equal "from_block", input.value
      end

      test "Input coerce does not overwrite value if already set" do
        input = Repeat::Input.new
        input.value = "original"
        input.coerce("overwritten")

        assert_equal "original", input.value
      end

      test "Output value returns final output from last iteration" do
        em1 = build_ran_manager("first_result")
        em2 = build_ran_manager("second_result")
        output = Repeat::Output.new([em1, em2])

        assert_equal "second_result", output.value
      end

      test "Output value returns nil when no iterations ran" do
        output = Repeat::Output.new([])

        assert_nil output.value
      end

      test "Output iteration returns Call::Output for valid index" do
        em = build_bare_manager
        output = Repeat::Output.new([em])

        result = output.iteration(0)
        assert_instance_of Call::Output, result
      end

      test "Output iteration supports negative indices" do
        em1 = build_bare_manager
        em2 = build_bare_manager
        output = Repeat::Output.new([em1, em2])

        result = output.iteration(-1)
        assert_instance_of Call::Output, result
      end

      test "Output iteration raises IndexError for out of bounds index" do
        output = Repeat::Output.new([build_bare_manager])

        assert_raises(IndexError) do
          output.iteration(5)
        end
      end

      test "Output first returns first iteration" do
        em = build_bare_manager
        output = Repeat::Output.new([em])

        result = output.first
        assert_instance_of Call::Output, result
      end

      test "Output last returns last iteration" do
        em1 = build_bare_manager
        em2 = build_bare_manager
        output = Repeat::Output.new([em1, em2])

        result = output.last
        assert_instance_of Call::Output, result
      end

      test "Output results returns Map::Output" do
        em = build_bare_manager
        output = Repeat::Output.new([em])

        result = output.results
        assert_instance_of Map::Output, result
      end

      # Integration tests use `outputs` blocks in inner scopes to unwrap raw values.
      # Without this, `em.final_output` returns a TestOutput wrapper, and subsequent
      # repeat iterations would receive TestOutput as their scope_value instead of
      # the raw value the cog produced.

      test "repeat executes scope until break! and produces correct output" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :loop_body) do |input|
              input.value = 0
            end
            outputs { collect(repeat(:my_repeat).results) }
          }],
          loop_body: [proc {
            test_cog(:step) do |_input, scope, _index|
              break! if scope >= 2
              scope + 1
            end
            outputs { test_cog(:step)&.value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal 1, results[0]
        assert_equal 2, results[1]
        assert_nil results[2]
      end

      test "repeat passes output from previous iteration as input to next" do
        received_values = []
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :accumulate) do |input|
              input.value = "start"
              input.max_iterations = 3
            end
            outputs { repeat(:my_repeat).value }
          }],
          accumulate: [proc {
            test_cog(:step) do |_input, scope, _index|
              received_values << scope
              "#{scope}+"
            end
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal ["start", "start+", "start++"], received_values
        assert_equal "start+++", manager.final_output
      end

      test "repeat respects max_iterations limit" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :limited) do |input|
              input.value = 1
              input.max_iterations = 3
            end
            outputs { repeat(:my_repeat).value }
          }],
          limited: [proc {
            test_cog(:step) { |_input, scope, _index| scope + 10 }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal 31, manager.final_output
      end

      test "repeat returns final output as value" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :return_test) do |input|
              input.value = 1
              input.max_iterations = 3
            end
            outputs { repeat(:my_repeat).value }
          }],
          return_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope * 2 }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal 8, manager.final_output
      end

      test "repeat passes incrementing scope_index to each inner execution" do
        received_indices = []
        exec_procs = {
          nil => [proc {
            repeat(run: :indexed) do |input|
              input.value = "x"
              input.max_iterations = 3
            end
          }],
          indexed: [proc {
            test_cog(:step) do |_input, _scope, index|
              received_indices << index
              "done"
            end
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal [0, 1, 2], received_indices
      end

      test "repeat handles ControlFlow::Break by stopping loop with completed iteration results" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :with_break) do |input|
              input.value = "a"
              input.max_iterations = 10
            end
            outputs { collect(repeat(:my_repeat).results) }
          }],
          with_break: [proc {
            test_cog(:step) do |_input, scope, index|
              break! if index >= 2
              "#{scope}#{index}"
            end
            outputs { test_cog(:step)&.value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        results = manager.final_output
        assert_equal 3, results.length
        assert_equal "a0", results[0]
        assert_equal "a01", results[1]
        assert_nil results[2]
      end

      test "collect on repeat results returns all iteration outputs" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :collect_test) do |input|
              input.value = 1
              input.max_iterations = 3
            end
            outputs { collect(repeat(:my_repeat).results) }
          }],
          collect_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope * 2 }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal [2, 4, 8], manager.final_output
      end

      test "reduce on repeat results accumulates values" do
        exec_procs = {
          nil => [proc {
            repeat(:my_repeat, run: :reduce_test) do |input|
              input.value = 1
              input.max_iterations = 3
            end
            outputs { reduce(repeat(:my_repeat).results, 0) { |sum, output, _item, _index| sum + output } }
          }],
          reduce_test: [proc {
            test_cog(:step) { |_input, scope, _index| scope * 2 }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal 14, manager.final_output
      end
    end
  end
end
