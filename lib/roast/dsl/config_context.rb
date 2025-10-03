# typed: false
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext
      def initialize(cogs, config_proc)
        @cogs = cogs
        @executor_scoped_configs = {}
        @cog_scoped_configs = {}
        @config_proc = config_proc
      end

      def fetch_merged_config(cog_class, name = nil)
        # All configs have an entry, even if it's empty.
        configs = fetch_execution_scope(cog_class)
        instance_configs = fetch_cog_config(cog_class, name) unless name.nil?
        configs = configs.merge(instance_configs) if instance_configs
        configs
      end

      def prepare!
        bind_default_cogs
        instance_eval(&@config_proc)
      end

      #: () -> void
      def bind_default_cogs
        bind_cog(Cogs::Cmd, :cmd)
      end

      def fetch_cog_config(cog_class, name)
        @cog_scoped_configs[cog_class][name]
      end

      def fetch_or_create_cog_config(cog_class, name)
        @cog_scoped_configs[cog_class][name] = cog_class.config_class.new unless @cog_scoped_configs.key?(name)
        @cog_scoped_configs[cog_class][name]
      end

      def fetch_execution_scope(cog_class)
        @executor_scoped_configs[cog_class]
      end

      def bind_cog(cog_class, method_name)
        @cog_scoped_configs[cog_class] = {}
        @executor_scoped_configs[cog_class] = cog_class.config_class.new
        instance_eval do
          define_singleton_method(method_name, &cog_class.on_config)
        end
      end
    end
  end
end
