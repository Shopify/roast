# frozen_string_literal: true

require "test_helper"

module Roast
  class ExecutionManagerTest < ActiveSupport::TestCase
    class TestInput < Cog::Input
      attr_accessor :value

      def validate!
        raise InvalidInputError if value.nil? && !coerce_ran?
      end

      def coerce(input_return_value)
        super
        @value = input_return_value
      end
    end

    class TestOutput < Cog::Output
      attr_reader :value

      def initialize(value)
        super()
        @value = value
      end
    end

    class TestCog < Cog
      class Config < Cog::Config; end
      class Input < TestInput; end

      def execute(input)
        TestOutput.new(input.value)
      end
    end

    def setup
      @registry = Cog::Registry.new
      @registry.use(TestCog)

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

    test "prepare! transitions to prepared state" do
      exec_proc = proc { test_cog(:step1) { "hello" } }
      manager = build_manager({ nil => [exec_proc] })

      refute manager.prepared?
      manager.prepare!
      assert manager.prepared?
    end

    test "prepare! raises when called twice" do
      manager = build_manager({ nil => [] })
      manager.prepare!

      assert_raises(ExecutionManager::ExecutionManagerAlreadyPreparedError) do
        manager.prepare!
      end
    end

    test "prepare! raises when scope does not exist" do
      manager = build_manager({}, scope: :nonexistent)

      assert_raises(ExecutionManager::ExecutionScopeDoesNotExistError) do
        manager.prepare!
      end
    end

    test "prepare! raises IllegalCogNameError when cog name conflicts with existing method" do
      conflicting_registry = Cog::Registry.new
      conflicting_cog = Class.new(Cog) do
        class << self
          def name
            "Roast::TestCogs::Freeze"
          end
        end
      end
      conflicting_registry.use(conflicting_cog)

      # Use a clean registry for config_manager so it doesn't hit the same conflict
      config_manager = ConfigManager.new(Cog::Registry.new, [])
      config_manager.prepare!

      manager = ExecutionManager.new(
        conflicting_registry, config_manager, { nil => [] }, @workflow_context
      )

      assert_raises(ExecutionManager::IllegalCogNameError) do
        manager.prepare!
      end
    end

    test "run! raises when not prepared" do
      manager = build_manager({ nil => [] })

      assert_raises(ExecutionManager::ExecutionManagerNotPreparedError) do
        manager.run!
      end
    end

    test "run! executes cogs in order and sets final_output to last cog output" do
      exec_proc = proc do
        test_cog(:step1) { "first" }
        test_cog(:step2) { "second" }
      end
      manager = build_manager({ nil => [exec_proc] })
      manager.prepare!
      manager.run!

      assert_equal "second", manager.final_output.value
    end

    test "run! uses outputs block for final_output when defined" do
      exec_proc = proc do
        test_cog(:step1) { "hello" }
        outputs { test_cog(:step1).value.upcase }
      end
      manager = build_manager({ nil => [exec_proc] })
      manager.prepare!
      manager.run!

      assert_equal "HELLO", manager.final_output
    end

    test "run! resets running state after completion" do
      exec_proc = proc do
        test_cog(:step1) { "value" }
      end
      manager = build_manager({ nil => [exec_proc] })
      manager.prepare!

      manager.run!
      refute manager.running?
    end

    test "run! executes with scope_value and scope_index" do
      received_scope = nil
      received_index = nil
      exec_proc = proc do
        test_cog(:step1) do |_input, scope, index|
          received_scope = scope
          received_index = index
          "done"
        end
      end
      manager = build_manager(
        { nil => [exec_proc] },
        scope_value: "my_value",
        scope_index: 3,
      )
      manager.prepare!
      manager.run!

      assert_equal "my_value", received_scope
      assert_equal 3, received_index
    end

    test "stop! does not raise when called before run!" do
      manager = build_manager({ nil => [] })
      manager.prepare!

      assert_nothing_raised { manager.stop! }
    end

    test "cog_input_context raises when not prepared" do
      manager = build_manager({ nil => [] })

      assert_raises(ExecutionManager::ExecutionManagerNotPreparedError) do
        manager.cog_input_context
      end
    end

    test "cog_input_context returns context after prepare" do
      manager = build_manager({ nil => [] })
      manager.prepare!

      assert_not_nil manager.cog_input_context
    end

    test "run! executes within a named scope" do
      exec_procs = {
        my_scope: [proc { test_cog(:scoped_step) { "scoped result" } }],
      }
      manager = build_manager(exec_procs, scope: :my_scope)
      manager.prepare!
      manager.run!

      assert_equal "scoped result", manager.final_output.value
    end

    test "outputs! raises OutputsAlreadyDefinedError when outputs already defined" do
      exec_proc = proc do
        test_cog(:step1) { "value" }
        outputs { "first" }
        outputs! { "second" }
      end
      manager = build_manager({ nil => [exec_proc] })

      assert_raises(ExecutionManager::OutputsAlreadyDefinedError) do
        manager.prepare!
      end
    end

    test "outputs raises OutputsAlreadyDefinedError when outputs! already defined" do
      exec_proc = proc do
        test_cog(:step1) { "value" }
        outputs! { "first" }
        outputs { "second" }
      end
      manager = build_manager({ nil => [exec_proc] })

      assert_raises(ExecutionManager::OutputsAlreadyDefinedError) do
        manager.prepare!
      end
    end

    test "run! propagates ControlFlow::Next from sync cog" do
      exec_proc = proc do
        test_cog(:step1) { raise ControlFlow::Next }
        test_cog(:step2) { "should not run" }
      end
      manager = build_manager({ nil => [exec_proc] })
      manager.prepare!

      assert_raises(ControlFlow::Next) do
        manager.run!
      end
    end

    test "run! propagates ControlFlow::Break from sync cog" do
      exec_proc = proc do
        test_cog(:step1) { raise ControlFlow::Break }
      end
      manager = build_manager({ nil => [exec_proc] })
      manager.prepare!

      assert_raises(ControlFlow::Break) do
        manager.run!
      end
    end
  end
end
