# frozen_string_literal: true

require "test_helper"

module Roast
  class ConfigManagerTest < ActiveSupport::TestCase
    class TestCogConfig < Cog::Config
      field :timeout, 30
    end

    class TestCog < Cog
      class Config < TestCogConfig; end

      def execute(_input)
        raise NotImplementedError
      end
    end

    def setup
      @registry = Cog::Registry.new
      @registry.use(TestCog)
    end

    def build_manager(config_procs = [], params: WorkflowParams.new([], [], {}))
      workflow_context = WorkflowContext.new(params:, tmpdir: Dir.tmpdir, workflow_dir: Pathname.pwd)
      ConfigManager.new(@registry, config_procs, workflow_context)
    end

    test "prepare! transitions to prepared state" do
      manager = build_manager

      refute manager.prepared?
      manager.prepare!
      assert manager.prepared?
    end

    test "prepare! raises when called twice" do
      manager = build_manager
      manager.prepare!

      assert_raises(ConfigManager::ConfigManagerAlreadyPreparedError) do
        manager.prepare!
      end
    end

    test "prepare! evaluates config procs in the config context" do
      timeout_set = false
      config_proc = proc do
        test_cog { timeout 60 }
        timeout_set = true
      end
      manager = build_manager([config_proc])
      manager.prepare!

      assert timeout_set
    end

    test "config_for raises when not prepared" do
      manager = build_manager

      assert_raises(ConfigManager::ConfigManagerNotPreparedError) do
        manager.config_for(TestCog)
      end
    end

    test "config_for returns default config when no config procs are provided" do
      manager = build_manager
      manager.prepare!

      config = manager.config_for(TestCog)

      assert_equal 30, config.timeout
    end

    test "config_for applies general cog configuration" do
      config_proc = proc do
        test_cog { timeout 60 }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      config = manager.config_for(TestCog)

      assert_equal 60, config.timeout
    end

    test "config_for applies name-scoped configuration" do
      config_proc = proc do
        test_cog(:my_step) { timeout 90 }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      scoped_config = manager.config_for(TestCog, :my_step)
      unscoped_config = manager.config_for(TestCog, :other_step)

      assert_equal 90, scoped_config.timeout
      assert_equal 30, unscoped_config.timeout
    end

    test "config_for applies regexp-scoped configuration" do
      config_proc = proc do
        test_cog(/^api_/) { timeout 120 }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      matching_config = manager.config_for(TestCog, :api_call)
      non_matching_config = manager.config_for(TestCog, :db_query)

      assert_equal 120, matching_config.timeout
      assert_equal 30, non_matching_config.timeout
    end

    test "config_for merges general and name-scoped configs" do
      config_proc = proc do
        test_cog { async! }
        test_cog(:my_step) { timeout 90 }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      config = manager.config_for(TestCog, :my_step)

      assert config.async?
      assert_equal 90, config.timeout
    end

    test "config_for applies global config to all cogs" do
      config_proc = proc do
        global { abort_on_failure! }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      config = manager.config_for(TestCog)

      assert config.abort_on_failure?
    end

    test "target! returns the single target inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = target! }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new(["Gemfile"], [], {}))
      manager.prepare!

      assert_equal "Gemfile", captured
    end

    test "target! raises inside a cog config block when not exactly one target" do
      config_proc = proc do
        test_cog { target! }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new(["a", "b"], [], {}))

      assert_raises(ArgumentError) do
        manager.prepare!
      end
    end

    test "targets returns the target array inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = targets }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new(["Gemfile", "Rakefile"], [], {}))
      manager.prepare!

      assert_equal ["Gemfile", "Rakefile"], captured
    end

    test "arg? returns true inside a cog config block when the flag is present" do
      captured = nil
      config_proc = proc do
        test_cog { captured = arg?(:big) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [:big], {}))
      manager.prepare!

      assert captured
    end

    test "arg? returns false inside a cog config block when the flag is absent" do
      captured = nil
      config_proc = proc do
        test_cog { captured = arg?(:big) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], {}))
      manager.prepare!

      refute captured
    end

    test "args returns the arg array inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = args }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [:hello, :world], {}))
      manager.prepare!

      assert_equal [:hello, :world], captured
    end

    test "kwarg returns the value inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = kwarg(:name) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { name: "test" }))
      manager.prepare!

      assert_equal "test", captured
    end

    test "kwarg returns nil inside a cog config block when the keyword is missing" do
      captured = :sentinel
      config_proc = proc do
        test_cog { captured = kwarg(:missing) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { name: "test" }))
      manager.prepare!

      assert_nil captured
    end

    test "kwarg! returns the value inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = kwarg!(:name) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { name: "test" }))
      manager.prepare!

      assert_equal "test", captured
    end

    test "kwarg! raises inside a cog config block when the keyword argument is missing" do
      config_proc = proc do
        test_cog { kwarg!(:name) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], {}))

      assert_raises(ArgumentError) do
        manager.prepare!
      end
    end

    test "kwarg? returns true inside a cog config block when the keyword is present" do
      captured = nil
      config_proc = proc do
        test_cog { captured = kwarg?(:name) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { name: "test" }))
      manager.prepare!

      assert captured
    end

    test "kwarg? returns false inside a cog config block when the keyword is missing" do
      captured = nil
      config_proc = proc do
        test_cog { captured = kwarg?(:missing) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { name: "test" }))
      manager.prepare!

      refute captured
    end

    test "kwargs returns the kwargs hash inside a cog config block" do
      captured = nil
      config_proc = proc do
        test_cog { captured = kwargs }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [], { foo: "bar" }))
      manager.prepare!

      assert_equal({ foo: "bar" }, captured)
    end

    test "workflow params are accessible inside a global config block" do
      config_proc = proc do
        global { abort_on_failure! if arg?(:strict) }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [:strict], {}))
      manager.prepare!

      assert manager.config_for(TestCog).abort_on_failure?
    end

    test "global with regexp specifier applies to matching cog names" do
      config_proc = proc do
        global(/^api_/) { async! }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      matching_config = manager.config_for(TestCog, :api_call)
      non_matching_config = manager.config_for(TestCog, :db_query)

      assert matching_config.async?
      refute non_matching_config.async?
    end

    test "global regexp does not apply when cog name is nil" do
      config_proc = proc do
        global(/.*/) { async! }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      config = manager.config_for(TestCog)

      refute config.async?
    end

    test "global cascade order: bare < regexp" do
      config_proc = proc do
        global { self[:priority] = "bare" }
        global(/my/) { self[:priority] = "regexp" }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      # Regexp global should win over bare
      config = manager.config_for(TestCog, :my_step)
      assert_equal "regexp", config.values[:priority]
    end

    test "multiple global regexps apply in insertion order" do
      config_proc = proc do
        global(/^a/) { self[:priority] = "first" }
        global(/api/) { self[:priority] = "second" }
      end
      manager = build_manager([config_proc])
      manager.prepare!

      # Both match :api_call — second one wins (applied last)
      config = manager.config_for(TestCog, :api_call)
      assert_equal "second", config.values[:priority]
    end

    test "workflow params are accessible inside a global regexp config block" do
      captured = nil
      config_proc = proc do
        global(/something_/) { captured = target! }
      end
      manager = build_manager([config_proc], params: WorkflowParams.new(["Gemfile"], [], {}))
      manager.prepare!

      assert_equal "Gemfile", captured
    end

    test "workflow params are not accessible in the top-level config block body" do
      config_proc = proc do
        args
      end
      manager = build_manager([config_proc], params: WorkflowParams.new([], [:big], {}))

      assert_raises(NameError) do
        manager.prepare!
      end
    end

    test "prepare! raises IllegalCogNameError when cog name conflicts with existing method" do
      # Register a cog whose derived name ("freeze") conflicts with Object#freeze
      conflicting_cog = Class.new(Cog) do
        class << self
          def name
            "Roast::TestCogs::Freeze"
          end
        end
      end
      @registry.use(conflicting_cog)

      manager = build_manager

      assert_raises(ConfigManager::IllegalCogNameError) do
        manager.prepare!
      end
    end
  end
end
