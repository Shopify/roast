# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Config
        class ConfigError < Roast::Error; end

        class InvalidConfigError < ConfigError; end

        # Validate that the config instance has all required parameters set in an acceptable manner
        #
        # Inheriting cog should implement this for its config class if validation is desired.
        #
        #: () -> void
        def validate!; end

        #: Hash[Symbol, untyped]
        attr_reader :values

        #: (?Hash[Symbol, untyped]) -> void
        def initialize(initial = {})
          @values = initial
        end

        #: (Cog::Config) -> Cog::Config
        def merge(config_object)
          self.class.new(values.merge(config_object.values))
        end

        # It is recommended to implement a custom config object for a nicer interface,
        # but for simple cases where it would just be a key value store we provide one by default.

        #: (Symbol, untyped) -> void
        def []=(key, value)
          @values[key] = value
        end

        #: (Symbol) -> untyped
        def [](key)
          @values[key]
        end

        class << self
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

        #: () -> void
        def exit_on_error!
          @values[:exit_on_error] = true
        end

        #: () -> void
        def no_exit_on_error!
          @values[:exit_on_error] = false
        end

        #: () -> bool
        def exit_on_error?
          @values[:exit_on_error] ||= true
        end

        #: () -> void
        def async!
          @values[:async] = true
        end

        #: () -> void
        def no_async!
          @values[:async] = false
        end

        #: () -> bool
        def async?
          !!@values[:async]
        end

        alias_method(:continue_on_error!, :no_exit_on_error!)
        alias_method(:sync!, :no_async!)
      end
    end
  end
end
