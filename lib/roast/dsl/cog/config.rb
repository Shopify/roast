# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Base configuration class for all cogs
      #
      # Provides common configuration methods and utilities for cog behavior.
      # Cogs extend this class to define their own configuration options using either
      # the `field` class method for simple fields or custom methods for complex configuration.
      class Config
        # Parent class for all configuration-related errors
        class ConfigError < Roast::Error; end

        # Raised when a configuration value is invalid or missing
        class InvalidConfigError < ConfigError; end

        # Validate that the config instance has all required parameters set in an acceptable manner
        #
        # Inheriting cogs should implement this method for their config class if validation is desired.
        # This method is called after configuration is complete to ensure all required values are present
        # and valid.
        #
        #: () -> void
        def validate!; end

        # The internal hash storing all configuration values
        #
        #: Hash[Symbol, untyped]
        attr_reader :values

        #: (?Hash[Symbol, untyped]) -> void
        def initialize(initial = {})
          @values = initial
        end

        # Merge another config object into this one, returning a new config instance
        #
        # Creates a new config object with values from both this config and the provided config.
        # Values from the provided config take precedence over values from this config.
        #
        # #### See Also
        # - `values`
        #
        #: (Cog::Config) -> Cog::Config
        def merge(config_object)
          self.class.new(values.merge(config_object.values))
        end

        # Set a configuration value using hash-style syntax
        #
        # This method provides basic key-value storage for cog configuration.
        # All standard Roast cogs use imperative setter methods for config values.
        # It is recommended that custom cogs implement their own config classes with similar methods
        # for a more structured interface, but this hash-style syntax is provided for simple cases.
        #
        # #### See Also
        # - `[]`
        #
        #: (Symbol, untyped) -> void
        def []=(key, value)
          @values[key] = value
        end

        # Get a configuration value using hash-style syntax
        #
        # This method provides basic key-value retrieval for cog configuration.
        # All standard Roast cogs use imperative setter methods for config values.
        # It is recommended that custom cogs implement their own config classes with similar methods
        # for a more structured interface, but this hash-style syntax is provided for simple cases.
        #
        # #### See Also
        # - `[]=`
        #
        #: (Symbol) -> untyped
        def [](key)
          @values[key]
        end

        class << self
          # Define a configuration field with simple, out-of-the-box getter/setter behavior
          # and default value handling
          #
          # #### Generated Methods
          # This method creates two methods for a configuration field:
          # 1. A dual-purpose method (`key`) that gets the value when called without arguments,
          #    or sets the value when called with an argument.
          # 2. A bang method (`use_default_#{key}!`) that explicitly resets the field to its default value.
          #
          # When getting a value without arguments, the configured value is returned if set,
          # otherwise the default value is returned.
          # When setting a value with an argument, the validator block is applied if provided.
          #
          # #### Validation
          #
          # This method accepts an optional `validator` block that will be called with the new value
          # when the field's setter method is invoked. The validator should raise an exception if the
          # provided value is not valid. It's return value will be used as the new config value.
          # This allows the validator to coerce an value into a standard form if desired.
          #
          # ##### See Also
          # - `Cog::Config#validate!` - validates the config object as a whole, after all values have been set
          #
          # #### Parameters
          # - `key` - The name of the configuration field
          # - `default` - The default value for this field
          # - `validator` - Optional block that validates and/or transforms the value before storing it
          #
          #: [T] (Symbol, T) ?{(T) -> T} -> void
          def field(key, default, &validator)
            default = default #: as untyped

            define_method(key) do |*args|
              if args.empty?
                # with no args, return the configured value, or the default
                @values[key] || default.deep_dup
              else
                # with an argument, set the configured value
                new_value = args.first
                @values[key] = validator ? validator.call(new_value) : new_value
              end
            end

            define_method("use_default_#{key}!".to_sym) do
              # explicitly set the configured value to the default
              @values[key] = default.deep_dup
            end
          end
        end

        # Configure the cog to run asynchronously in the background
        #
        # When configured to run asynchronously, the cog will execute in the background
        # and the next cog in the workflow will be able to start immediately without waiting
        # for this cog to complete.
        #
        # If this cog has started running, attempts to access its output from another cog will
        # block until this cog completes.
        # If this cog has not yet started, attempts to access its output from another cog will
        # fail in the same way that accessing the output of a synchronous cog that has not yet
        # run would fail.
        #
        # The workflow will not complete until all asynchronous cogs have completed (or failed).
        #
        # #### Inverse Methods
        # - `no_async!`
        # - `sync!`
        #
        # #### See Also
        # - `async?`
        #
        #: () -> void
        def async!
          @values[:async] = true
        end

        # Configure the cog __not__ to run asynchronously
        #
        # When configured not to run asynchronously, the cog will execute synchronously
        # and the next cog in the workflow will wait for this cog to complete before starting.
        #
        # #### Alias Methods
        # - `no_async!`
        # - `sync!`
        #
        # #### Inverse Methods
        # - `async!`
        #
        # #### See Also
        # - `async?`
        #
        #: () -> void
        def no_async!
          @values[:async] = false
        end

        # Check if the cog is configured to run asynchronously
        #
        # #### See Also
        # - `async!`
        # - `no_async!`
        # - `sync!`
        #
        #: () -> bool
        def async?
          !!@values[:async]
        end

        # Configure the cog to abort the workflow immediately if it fails to complete successfully
        #
        # Enabled by default.
        #
        # #### Inverse Methods
        # - `continue_on_failure!`
        # - `no_abort_on_failure!`
        #
        # #### See Also
        # - `abort_on_failure?`
        #
        #: () -> void
        def abort_on_failure!
          @values[:abort_on_failure] = true
        end

        # Configure the cog __not__ to abort the workflow if it fails to complete successfully
        #
        # When a cog is configured not to abort on failure, the workflow will continue to run subsequent cogs
        # even if a cog fails. However, attempts to access that cog's output from another cog will fail.
        #
        # #### Alias Methods
        # - `continue_on_failure!`
        #
        # #### Inverse Methods
        # - `abort_on_failure!`
        #
        # #### See Also
        # - `abort_on_failure?`
        #
        #: () -> void
        def no_abort_on_failure!
          @values[:abort_on_failure] = false
        end

        # Check if the cog is configured to abort the workflow immediately on failure
        #
        # #### See Also
        # - `abort_on_failure!`
        # - `continue_on_failure!`
        # - `no_abort_on_failure!`
        #
        #: () -> bool
        def abort_on_failure?
          !!@values[:abort_on_failure]
        end

        # Configure the cog to run external commands in the specified working directory
        #
        # The directory given can be relative or absolute.
        # If relative, it will be understood in relation to the directory from which Roast is invoked.
        #
        # ---
        #
        # __Important Note__: this configuration option only applies to external commands invoked by a cog
        # It does not affect the working directory in which Roast is running.
        #
        # ---
        #
        # #### See Also
        # - `use_current_working_directory!`
        # - `valid_working_directory`
        #
        #: (String) -> void
        def working_directory(directory)
          @values[:working_directory] = directory
        end

        # Configure the cog to run in the directory from which Roast is invoked
        #
        # ---
        #
        # __Important Note__: this configuration option only applies to external commands invoked by a cog
        # It does not affect the working directory in which Roast is running.
        #
        # ---
        #
        # #### See Also
        # - `working_directory`
        # - `valid_working_directory`
        #
        #: () -> void
        def use_current_working_directory!
          @values[:working_directory] = nil
        end

        # Get the validated, configured value for the working directory path in which the cog should run
        #
        # A value of `nil` means to use the current working directory.
        # This method will raise an `InvalidConfigError` if the path does not exist or is not a directory.
        #
        # ---
        #
        # __Important Note__: this configuration option only applies to external commands invoked by a cog
        # It does not affect the working directory in which Roast is running.
        #
        # ---
        #
        # #### See Also
        # - `working_directory`
        # - `use_current_working_directory!`
        #
        #: () -> Pathname?
        def valid_working_directory
          path = Pathname.new(@values[:working_directory]).expand_path if @values[:working_directory]
          return unless path
          raise InvalidConfigError, "working directory '#{path}' does not exist'" unless path.exist?
          raise InvalidConfigError, "working directory '#{path}' is not a directory'" unless path.directory?

          path
        end

        alias_method(:continue_on_failure!, :no_abort_on_failure!)
        alias_method(:sync!, :no_async!)
      end
    end
  end
end
