# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Config
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
          def field(key, default)
            define_method(key) do |*args|
              if args.empty?
                if @values[key].nil?
                  @values[key] = default
                end

                @values[key]
              else
                @values[key] = args.first
              end
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

        alias_method(:continue_on_error!, :no_exit_on_error!)
      end
    end
  end
end
