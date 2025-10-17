# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigManager
      class ConfigManagerError < Roast::Error; end
      class ConfigManagerNotPreparedError < ConfigManagerError; end
      class ConfigManagerAlreadyPreparedError < ConfigManagerError; end

      #: (Cog::Registry, Array[^() -> void]) -> void
      def initialize(cog_registry, config_procs)
        @cog_registry = cog_registry
        @config_procs = config_procs
        @config_context = ConfigContext.new #: ConfigContext
        @general_configs = {} #: Hash[singleton(Cog), Cog::Config]
        @name_scoped_configs = {} #: Hash[singleton(Cog), Hash[Symbol, Cog::Config]]
      end

      #: () -> void
      def prepare!
        raise ConfigManagerAlreadyPreparedError if preparing? || prepared?

        @preparing = true
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
        config = fetch_general_config(cog_class)
        name_scoped_config = fetch_name_scoped_config(cog_class, name) unless name.nil?
        config = config.merge(name_scoped_config) if name_scoped_config
        config
      end

      private

      #: (singleton(Cog)) -> Cog::Config
      def fetch_general_config(cog_class)
        @general_configs[cog_class] ||= cog_class.config_class.new
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
        cog_method = proc do |cog_name = nil, &cog_config_proc|
          on_config_method.call(cog_class, cog_name, &cog_config_proc)
        end
        @config_context.instance_eval do
          define_singleton_method(cog_method_name, cog_method)
        end
      end

      #: (singleton(Cog), Symbol) { () -> void } -> void
      def on_config(cog_class, cog_name, &cog_config_proc)
        # Called when the cog method is invoked in the workflow's 'config' block.
        # This allows configuration parameters to be set for the cog generally or for a specific named instance
        config_object = if cog_name.nil?
          fetch_general_config(cog_class)
        else
          fetch_name_scoped_config(cog_class, cog_name)
        end
        # NOTE: Sorbet expects the proc passed to instance_exec to be declared as taking an argument
        # but our cog_config_proc does not get an argument
        config_object.instance_exec(&T.unsafe(cog_config_proc)) if cog_config_proc
        config_object
      end
    end
  end
end
