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
      @global_config = Cog::Config.new #: Cog::Config
      @global_regexp_configs = {} #: Hash[Regexp, Cog::Config]
      @general_configs = {} #: Hash[singleton(Cog), Cog::Config]
      @regexp_scoped_configs = {} #: Hash[singleton(Cog), Hash[Regexp, Cog::Config]]
      @name_scoped_configs = {} #: Hash[singleton(Cog), Hash[Symbol, Cog::Config]]
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

      # All cogs will always have a config; empty by default if the cog was never explicitly configured
      # Start with bare global config
      config = cog_class.config_class.new(@global_config.values.deep_dup)
      # Apply cog-type general config
      config = config.merge(fetch_general_config(cog_class))
      unless name.nil?
        # Apply matching global regexp configs (insertion order)
        @global_regexp_configs.each do |pattern, cfg|
          config = config.merge(cfg) if pattern.match?(name.to_s)
        end
        # Apply cog-type regexp configs
        @regexp_scoped_configs.fetch(cog_class, {}).select do |pattern, _|
          pattern.match?(name.to_s)
        end.values.each { |cfg| config = config.merge(cfg) }
        # NOTE: global name configs are not implemented, since names must be unique across all cog types
        # Apply cog-type name config
        name_scoped_config = fetch_name_scoped_config(cog_class, name)
        config = config.merge(name_scoped_config)
      end
      config.validate!
      config
    end

    private

    #: (singleton(Cog)) -> Cog::Config
    def fetch_general_config(cog_class)
      @general_configs[cog_class] ||= cog_class.config_class.new
    end

    #: (singleton(Cog), Regexp) -> Cog::Config
    def fetch_regexp_scoped_config(cog_class, pattern)
      regexp_scoped_configs_for_cog = @regexp_scoped_configs[cog_class] ||= {}
      regexp_scoped_configs_for_cog[pattern] ||= cog_class.config_class.new
    end

    #: (singleton(Cog), Symbol) -> Cog::Config
    def fetch_name_scoped_config(cog_class, name)
      name_scoped_configs_for_cog = @name_scoped_configs[cog_class] ||= {}
      name_scoped_configs_for_cog[name] ||= cog_class.config_class.new
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
      # Called when the cog method is invoked in the workflow's 'config' block.
      # This allows configuration parameters to be set for the cog generally or for a specific named instance

      # NOTE: cast to untyped is to intentional handling the 'unreachable' else case here.
      # This method takes user input directly so additional validation with a clearer exception message will be helpful
      cog_name_or_pattern = cog_name_or_pattern #: untyped
      config_object = case cog_name_or_pattern
      when NilClass
        fetch_general_config(cog_class)
      when Regexp
        fetch_regexp_scoped_config(cog_class, cog_name_or_pattern)
      when Symbol
        fetch_name_scoped_config(cog_class, cog_name_or_pattern)
      else
        raise ArgumentError, "Invalid type '#{cog_name_or_pattern.class}' for cog_name_or_pattern"
      end

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

    #: (Regexp?, ^() -> void) -> void
    def on_global(pattern, global_config_proc)
      # Called when the 'global' method is invoked in the workflow's 'config' block.
      # This allows common configuration parameters to be set for all cogs, or cogs of all types matching a pattern

      # NOTE: cast to untyped is to intentional handling the 'unreachable' else case here.
      # This method takes user input directly so additional validation with a clearer exception message will be helpful
      pattern = pattern #: untyped
      config_object = case pattern
      when NilClass
        @global_config
      when Regexp
        @global_regexp_configs[pattern] ||= Cog::Config.new
      else
        raise ArgumentError, "Invalid type '#{pattern.class}' for global pattern"
      end

      # NOTE: Sorbet expects the proc passed to instance_exec to be declared as taking an argument
      # but our global_config_proc does not get an argument
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
