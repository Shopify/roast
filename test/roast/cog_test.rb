# frozen_string_literal: true

require "test_helper"

module Roast
  class CogTest < ActiveSupport::TestCase
    TestCog = TestCogSupport::TestCog

    def setup
      @cog = TestCog.new(:test_cog, ->(_input, _scope, _index) { "hello" })
    end

    test "config_class returns Cog::Config by default for anonymous subclass" do
      anonymous_cog = Class.new(Cog)

      assert_equal Cog::Config, anonymous_cog.config_class
    end

    test "config_class returns child Config when defined" do
      assert_equal TestCog::Config, TestCog.config_class
    end

    test "input_class returns Cog::Input by default for anonymous subclass" do
      anonymous_cog = Class.new(Cog)

      assert_equal Cog::Input, anonymous_cog.input_class
    end

    test "input_class returns child Input when defined" do
      assert_equal TestCog::Input, TestCog.input_class
    end

    test "generate_fallback_name returns unique values" do
      names = 5.times.map { Cog.generate_fallback_name }

      assert_equal 5, names.uniq.size
    end

    test "name returns the name provided at initialization" do
      assert_equal :test_cog, @cog.name
    end

    test "output is nil before execution" do
      assert_nil @cog.output
    end

    test "started? returns false before execution" do
      refute @cog.started?
    end

    test "skipped? returns false before execution" do
      refute @cog.skipped?
    end

    test "failed? returns false before execution" do
      refute @cog.failed?
    end

    test "stopped? returns false before execution" do
      refute @cog.stopped?
    end

    test "succeeded? returns false before execution" do
      refute @cog.succeeded?
    end

    test "run! executes cog and sets output" do
      run_cog(@cog)

      assert @cog.succeeded?
      assert_equal "hello", @cog.output.value
    end

    test "run! sets started? to true" do
      run_cog(@cog)

      assert @cog.started?
    end

    test "stopped? returns false after successful execution" do
      run_cog(@cog)

      refute @cog.stopped?
    end

    test "stopped? returns true when task is explicitly stopped" do
      cog = TestCog.new(:long_cog, ->(_input, _scope, _index) {
        sleep 10
      })

      Sync do
        barrier = Async::Barrier.new
        input_context = Roast::CogInputContext.new
        config = cog.class.config_class.new

        cog.run!(barrier, config, input_context, nil, 0)
        barrier.stop

        assert cog.stopped?
      end
    end

    test "run! raises CogAlreadyStartedError when called twice" do
      run_cog(@cog)

      assert_raises(Cog::CogAlreadyStartedError) do
        run_cog(@cog)
      end
    end

    test "run! passes scope_value and scope_index to input proc" do
      received_scope = nil
      received_index = nil
      cog = TestCog.new(:scope_cog, ->(_input, scope, index) {
        received_scope = scope
        received_index = index
        "result"
      })

      run_cog(cog, scope_value: "my_scope", scope_index: 7)

      assert_equal "my_scope", received_scope
      assert_equal 7, received_index
    end

    test "run! marks cog as skipped when SkipCog is raised" do
      cog = TestCog.new(:skip_cog, ->(_input, _scope, _index) {
        raise ControlFlow::SkipCog
      })

      run_cog(cog)

      assert cog.skipped?
      refute cog.failed?
      refute cog.succeeded?
      assert_nil cog.output
    end

    test "run! marks cog as failed when FailCog is raised" do
      cog = TestCog.new(:fail_cog, ->(_input, _scope, _index) {
        raise ControlFlow::FailCog
      })

      run_cog(cog)

      assert cog.failed?
      refute cog.skipped?
      refute cog.succeeded?
      assert_nil cog.output
    end

    test "run! re-raises FailCog when abort_on_failure is configured" do
      cog = TestCog.new(:fail_cog, ->(_input, _scope, _index) {
        raise ControlFlow::FailCog
      })
      config = TestCog::Config.new
      config.abort_on_failure!

      assert_raises(ControlFlow::FailCog) do
        run_cog(cog, config: config)
      end
    end

    test "run! marks cog as skipped and re-raises on ControlFlow::Next" do
      cog = TestCog.new(:next_cog, ->(_input, _scope, _index) {
        raise ControlFlow::Next
      })

      assert_raises(ControlFlow::Next) do
        run_cog(cog)
      end

      assert cog.skipped?
    end

    test "run! marks cog as skipped and re-raises on ControlFlow::Break" do
      cog = TestCog.new(:break_cog, ->(_input, _scope, _index) {
        raise ControlFlow::Break
      })

      assert_raises(ControlFlow::Break) do
        run_cog(cog)
      end

      assert cog.skipped?
    end

    test "run! marks cog as failed and re-raises on StandardError" do
      cog = TestCog.new(:error_cog, ->(_input, _scope, _index) {
        raise "something went wrong"
      })

      assert_raises(RuntimeError) do
        run_cog(cog)
      end

      assert cog.failed?
    end

    test "wait does not raise when cog task raised an exception" do
      cog = TestCog.new(:error_cog, ->(_input, _scope, _index) {
        raise "boom"
      })

      begin
        run_cog(cog)
      rescue RuntimeError
        # expected
      end

      assert_nothing_raised do
        cog.wait
      end
    end

    test "wait does nothing when cog has not been started" do
      assert_nothing_raised do
        @cog.wait
      end
    end

    test "run! coerces input from proc return value" do
      cog = TestCog.new(:coerce_cog, ->(_input, _scope, _index) {
        { key: "value" }
      })

      run_cog(cog)

      assert cog.succeeded?
      assert_equal({ key: "value" }, cog.output.value)
    end

    test "run! allows input to be set directly in the proc" do
      cog = TestCog.new(:direct_input_cog, ->(input, _scope, _index) {
        input.value = "set directly"
      })

      run_cog(cog)

      assert cog.succeeded?
      assert_equal "set directly", cog.output.value
    end

    test "run! supports skip! from input context" do
      cog = TestCog.new(:skip_context_cog, ->(_input, _scope, _index) {
        skip!
      })

      run_cog(cog)

      assert cog.skipped?
      refute cog.failed?
      refute cog.succeeded?
      assert_nil cog.output
    end

    test "run! supports fail! from input context" do
      cog = TestCog.new(:fail_context_cog, ->(_input, _scope, _index) {
        fail!
      })

      run_cog(cog)

      assert cog.failed?
      refute cog.skipped?
      refute cog.succeeded?
      assert_nil cog.output
    end

    class BareCog < Cog; end

    test "run! raises NotImplementedError when execute is not implemented" do
      cog = BareCog.new(:bare_cog, ->(_input, _scope, _index) { "value" })

      assert_raises(NotImplementedError) do
        run_cog(cog)
      end
    end
  end
end
