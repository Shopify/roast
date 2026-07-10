# typed: true
# frozen_string_literal: true

module Roast
  class ConfigManager
    include WorkflowParamAccessors

    class ConfigManagerError < Roast::Error; end
    class ConfigManagerNotPreparedError < ConfigManagerError; end
    class ConfigManagerAlreadyPreparedError < ConfigManagerError; end
    class IllegalCogNameError < ConfigManagerError; end

    #: (Cog::Registry, Array[^() -> void], WorkflowContext) -> void
    def initialize(cog_registry, config_procs, workflow_context)
      @cog_registry = cog_registry
      @config_procs = config_procs
      @workflow_context = workflow_context
      @config_context = ConfigContext.new #: ConfigContext
      @global_tier = ConfigTier.new { Cog::Config.new }
      @cog_tiers = {} #: Hash[singleton(Cog), ConfigTier]
    end

    #: () -> void
    def prepare!
      raise ConfigManagerAlreadyPreparedError if preparing? || prepared?

      @preparing = true
      bind_global
      bind_registered_cogs
      @config_procs.each { |cp| @config_context.instance_eval(&cp) }
      @prepared = true
    end

    #: () -> bool
    def preparing?
      @preparing ||= false
    end

    #: () -> bool
    def prepared?
      @prepared ||= false
    end

    #: (singleton(Cog), ?Symbol?) -> Cog::Config
    def config_for(cog_class, name = nil)
      raise ConfigManagerNotPreparedError unless prepared?

      # Seed with the global general config values, constructing the cog-specific type
      config = cog_class.config_class.new(@global_tier.general_config.values.deep_dup)

      # Merge remaining global layers (matching regexps and name-scoped)
      @global_tier.resolve(name).drop(1).each { |cfg| config = config.merge(cfg) }

      # Apply the full cog-specific tier cascade (general, regexps, name)
      cog_tier_for(cog_class).resolve(name).each { |cfg| config = config.merge(cfg) }

      config.validate!
      config
    end

    private

    #: (singleton(Cog)) -> ConfigTier
    def cog_tier_for(cog_class)
      @cog_tiers[cog_class] ||= ConfigTier.new { cog_class.config_class.new }
    end

    #: () -> void
    def bind_registered_cogs
      @cog_registry.cogs.each { |cog_method_name, cog_class| bind_cog(cog_method_name, cog_class) }
    end

    #: (Symbol, singleton(Cog)) -> void
    def bind_cog(cog_method_name, cog_class)
      on_config_method = method(:on_config)
      cog_method = proc do |cog_name_or_pattern = nil, &cog_config_proc|
        on_config_method.call(cog_class, cog_name_or_pattern, cog_config_proc)
      end
      @config_context.instance_eval do
        raise IllegalCogNameError, cog_method_name if respond_to?(cog_method_name, true)

        define_singleton_method(cog_method_name, cog_method)
      end
    end

    #: (singleton(Cog), (Symbol | Regexp)?, ^() -> void ) -> void
    def on_config(cog_class, cog_name_or_pattern, cog_config_proc)
      config_object = cog_tier_for(cog_class).fetch(cog_name_or_pattern)

      # NOTE: Sorbet expects the proc passed to instance_exec to be declared as taking an argument
      # but our cog_config_proc does not get an argument
      cog_config_proc = cog_config_proc #: as ^(untyped) -> void
      bind_workflow_params(config_object)
      config_object.instance_exec(&cog_config_proc) if cog_config_proc
      nil
    end

    def bind_global
      on_global_method = method(:on_global)
      method_to_bind = proc do |name_or_pattern = nil, &global_proc|
        on_global_method.call(name_or_pattern, global_proc)
      end
      @config_context.instance_eval do
        define_singleton_method(:global, method_to_bind)
      end
    end

    #: ((Symbol | Regexp)?, ^() -> void ) -> void
    def on_global(name_or_pattern, global_config_proc)
      config_object = @global_tier.fetch(name_or_pattern)
      global_config_proc = global_config_proc #: as ^(untyped) -> void
      bind_workflow_params(config_object)
      config_object.instance_exec(&global_config_proc) if global_config_proc
      nil
    end

    #: (Cog::Config) -> void
    def bind_workflow_params(object)
      target_bang_method = method(:target!)
      targets_method = method(:targets)
      arg_question_method = method(:arg?)
      args_method = method(:args)
      kwarg_method = method(:kwarg)
      kwarg_bang_method = method(:kwarg!)
      kwarg_question_method = method(:kwarg?)
      kwargs_method = method(:kwargs)
      object.instance_eval do
        define_singleton_method(:target!, proc { target_bang_method.call })
        define_singleton_method(:targets, proc { targets_method.call })
        define_singleton_method(:arg?, proc { |value| arg_question_method.call(value) })
        define_singleton_method(:args, proc { args_method.call })
        define_singleton_method(:kwarg, proc { |key| kwarg_method.call(key) })
        define_singleton_method(:kwarg!, proc { |key| kwarg_bang_method.call(key) })
        define_singleton_method(:kwarg?, proc { |key| kwarg_question_method.call(key) })
        define_singleton_method(:kwargs, proc { kwargs_method.call })
      end
    end
  end
end
