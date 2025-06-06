# frozen_string_literal: true

module Roast
  module Helpers
    # Intercepts function dispatching to add caching capabilities
    # This module wraps around Raix::FunctionDispatch to provide caching for tool functions
    module FunctionCachingInterceptor
      def dispatch_tool_function(function_name, params)
        start_time = Time.now

        ActiveSupport::Notifications.instrument("roast.tool.execute", {
          function_name: function_name,
          params: params,
        })

        # Handle workflows with or without configuration
        result = if !respond_to?(:configuration) || configuration.nil?
          super(function_name, params)
        else
          function_config = if configuration.respond_to?(:function_config)
            configuration.function_config(function_name)
          else
            {}
          end

          # Check if caching is enabled - handle both formats:
          # 1. cache: true (boolean format)
          # 2. cache: { enabled: true } (hash format)
          cache_enabled = if function_config.is_a?(Hash)
            cache_config = function_config["cache"]
            if cache_config.is_a?(Hash)
              cache_config["enabled"]
            else
              # Direct boolean value
              cache_config
            end
          else
            false
          end

          if cache_enabled
            # Call the original function and pass in the cache
            super(function_name, params, cache: Roast::Tools::CACHE)
          else
            Roast::Helpers::Logger.debug("⚠️ Caching not enabled for #{function_name}")
            super(function_name, params)
          end
        end

        execution_time = Time.now - start_time

        # Determine if caching was enabled for metrics
        cache_enabled = if defined?(function_config) && function_config.is_a?(Hash)
          cache_config = function_config["cache"]
          if cache_config.is_a?(Hash)
            cache_config["enabled"]
          else
            # Direct boolean value
            cache_config
          end
        else
          false
        end

        ActiveSupport::Notifications.instrument("roast.tool.complete", {
          function_name: function_name,
          execution_time: execution_time,
          cache_enabled: cache_enabled,
        })

        result
      rescue => e
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.tool.error", {
          function_name: function_name,
          error: e.class.name,
          message: e.message,
          execution_time: execution_time,
        })
        raise
      end
    end
  end
end
