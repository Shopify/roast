# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConfigContext
      class ConfigContextError < Roast::Error; end
      class ConfigContextNotPreparedError < ConfigContextError; end
      class ConfigContextAlreadyPreparedError < ConfigContextError; end

      #: (Cog::Store, Array[^() -> void]) -> void
      def initialize(cogs, config_procs)
        @cogs = cogs #: Cog::Store
        @general_configs = {} #: Hash[singleton(Cog), Cog::Config]
        @name_scoped_configs = {} #: Hash[singleton(Cog), Hash[Symbol, Cog::Config]]
        @config_procs = config_procs #: Array[^() -> void]
      end

      #: () -> void
      def prepare!
        raise ConfigContextAlreadyPreparedError if prepared?

        bind_default_cogs
        @config_procs.each { |cp| instance_eval(&cp) }
        @prepared = true
      end

      #: () -> bool
      def prepared?
        @prepared ||= false
      end

      #: (singleton(Cog), ?Symbol?) -> Cog::Config
      def fetch_merged_config(cog_class, name = nil)
        raise ConfigContextNotPreparedError unless prepared?

        # All cogs will always have a config; empty by default if the cog was never explicitly configured
        config = fetch_general_config(cog_class)
        name_scoped_config = fetch_name_scoped_config(cog_class, name) unless name.nil?
        config = config.merge(name_scoped_config) if name_scoped_config
        config
      end

      #: (singleton(Cog)) -> Cog::Config
      def fetch_general_config(cog_class)
        @general_configs[cog_class] ||= cog_class.config_class.new
      end

      #: (singleton(Cog), Symbol) -> Cog::Config
      def fetch_name_scoped_config(cog_class, name)
        name_scoped_configs_for_cog = @name_scoped_configs[cog_class] ||= {}
        name_scoped_configs_for_cog[name] ||= cog_class.config_class.new
      end

      private

      #: () -> void
      def bind_default_cogs
        bind_cog(Cogs::Cmd, :cmd)
      end

      #: (singleton(Cog), Symbol) -> void
      def bind_cog(cog_class, method_name)
        instance_eval do
          define_singleton_method(method_name, &cog_class.on_config)
        end
      end
    end
  end
end
