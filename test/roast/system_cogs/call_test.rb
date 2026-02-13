# frozen_string_literal: true

require "test_helper"

module Roast
  module SystemCogs
    class CallTest < ActiveSupport::TestCase
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

      test "Params stores name and run scope" do
        params = Call::Params.new(:my_call, run: :my_scope)

        assert_equal :my_call, params.name
        assert_equal :my_scope, params.run
      end

      test "Params auto-generates name when not provided" do
        params = Call::Params.new(run: :my_scope)

        assert_kind_of Symbol, params.name
        assert_equal :my_scope, params.run
      end

      test "Input validate! passes when value is set" do
        input = Call::Input.new
        input.value = "hello"

        assert_nothing_raised { input.validate! }
      end

      test "Input validate! raises when value is nil and coerce has not run" do
        input = Call::Input.new

        assert_raises(Cog::Input::InvalidInputError) do
          input.validate!
        end
      end

      test "Input validate! passes when value is nil after coerce" do
        input = Call::Input.new
        input.coerce(nil)

        assert_nothing_raised { input.validate! }
      end

      test "Input index defaults to 0" do
        input = Call::Input.new

        assert_equal 0, input.index
      end

      test "Input coerce sets value from return value" do
        input = Call::Input.new
        input.coerce("from_block")

        assert_equal "from_block", input.value
      end

      test "Input coerce does not overwrite value if already set" do
        input = Call::Input.new
        input.value = "original"
        input.coerce("overwritten")

        assert_equal "original", input.value
      end

      # Integration tests use `outputs` blocks in inner scopes to unwrap raw values.
      # Without this, `em.final_output` returns a TestOutput wrapper instead of
      # the raw value the cog produced.

      test "call passes value and index to scope" do
        received_scope = nil
        received_index = nil
        exec_procs = {
          nil => [proc {
            call(run: :capture) do |input|
              input.value = "my_value"
              input.index = 42
            end
          }],
          capture: [proc {
            test_cog(:step) do |_input, scope, index|
              received_scope = scope
              received_index = index
              "done"
            end
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "my_value", received_scope
        assert_equal 42, received_index
      end

      test "call handles ControlFlow::Break by ending execution early" do
        exec_procs = {
          nil => [proc {
            call(:my_call, run: :with_break) do |input|
              input.value = "start"
            end
            outputs { from(call(:my_call)) }
          }],
          with_break: [
            proc {
              test_cog(:first) { |_input, scope, _index| "#{scope}_first" }
              outputs { test_cog(:first).value }
            },
            proc {
              test_cog(:second) do |_input, _scope, _index|
                break!
                "unreachable"
              end
            },
          ],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "start_first", manager.final_output
      end

      test "call handles ControlFlow::Next by ending execution early" do
        exec_procs = {
          nil => [proc {
            call(:my_call, run: :with_next) do |input|
              input.value = "start"
            end
            outputs { from(call(:my_call)) }
          }],
          with_next: [
            proc {
              test_cog(:first) { |_input, scope, _index| "#{scope}_first" }
              outputs { test_cog(:first).value }
            },
            proc {
              test_cog(:second) do |_input, _scope, _index|
                next!
                "unreachable"
              end
            },
          ],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "start_first", manager.final_output
      end

      test "from without block returns final output of called scope" do
        exec_procs = {
          nil => [proc {
            call(:my_call, run: :simple) { "input_val" }
            outputs { from(call!(:my_call)) }
          }],
          simple: [proc {
            test_cog(:step) { |_input, scope, _index| scope.upcase }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "INPUT_VAL", manager.final_output
      end

      test "from with block executes block in called scope context" do
        exec_procs = {
          nil => [proc {
            call(:my_call, run: :multi_step) { "data" }
            outputs { from(call!(:my_call)) { |final_output, scope_value, _index| "#{final_output}:#{scope_value}" } }
          }],
          multi_step: [proc {
            test_cog(:step) { |_input, scope, _index| scope.upcase }
            outputs { test_cog(:step).value }
          }],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "DATA:data", manager.final_output
      end

      test "from with block can access inner cog outputs" do
        exec_procs = {
          nil => [proc {
            call(:my_call, run: :two_steps) { "hello" }
            outputs { from(call!(:my_call)) { test_cog(:first).value } }
          }],
          two_steps: [
            proc {
              test_cog(:first) { |_input, scope, _index| "#{scope}_1" }
            },
            proc {
              test_cog(:second) { |_input, _scope, _index| "final" }
            },
          ],
        }
        manager = build_manager(exec_procs)
        manager.prepare!
        manager.run!

        assert_equal "hello_1", manager.final_output
      end
    end
  end
end
