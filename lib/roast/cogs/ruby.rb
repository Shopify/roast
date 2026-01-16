# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Ruby < Cog
      class Config < Cog::Config; end

      # Input specification for the ruby cog
      #
      # The ruby cog accepts any Ruby value from the input block, which will be directly
      # passed through to the output without modification.
      class Input < Cog::Input
        # The value to pass through to the output
        #
        # This value will be directly returned as the `value` attribute on the cog's output object.
        #
        #: untyped
        attr_accessor :value

        # Validate that the input has all required parameters
        #
        # This method ensures that a value has been provided, either directly via the `value`
        # attribute or through the input block (via `coerce`).
        #
        # #### See Also
        # - `coerce`
        #
        #: () -> void
        def validate!
          raise Cog::Input::InvalidInputError if value.nil? && !coerce_ran?
        end

        # Coerce the input from the return value of the input block
        #
        # The return value from the input block will be used directly as the `value` attribute.
        # This allows any Ruby object to be passed through the ruby cog.
        #
        # #### See Also
        # - `validate!`
        #
        #: (untyped) -> void
        def coerce(input_return_value)
          super
          @value = input_return_value
        end
      end

      # Output from running the ruby cog
      #
      # Contains the value that was provided to the input block, passed through unchanged.
      # This allows Ruby values to be used directly in workflow steps.
      #
      # The output provides convenient dynamic method dispatch with the following priority:
      # 1. If the value object responds to a method, it delegates to that method
      # 2. If the value is a Hash, methods correspond to hash keys
      # 3. Hash values that are Procs can be called directly as methods
      #
      # Additional conveniences:
      # - Use `[]` for direct hash key access when the value is a Hash
      # - Use `call()` to invoke the value if it's a Proc, or to call a Proc stored in a Hash
      class Output < Cog::Output
        # The value passed through from the input
        #
        #: untyped
        attr_reader :value

        #: (untyped) -> void
        def initialize(value)
          super()
          @value = value
        end

        # Access a hash key directly when the value is a Hash
        #
        # Provides direct bracket notation access to hash keys without going through
        # method dispatch. This is useful when you need explicit hash key access.
        #
        # #### See Also
        # - `call`
        # - `method_missing`
        #
        #: (Symbol) -> untyped
        def [](key)
          value[key]
        end

        # Call the value as a Proc, or call a Proc stored in a Hash
        #
        # This method provides two calling patterns:
        # - If the value is a Proc, calls it directly with the provided arguments
        # - If the value is a Hash, expects the first argument to be a Symbol key, retrieves
        #   the Proc at that key, and calls it with the remaining arguments
        #
        # Raises `ArgumentError` if called on a Hash without a Symbol key.
        # Raises `NoMethodError` if the Hash key doesn't contain a Proc.
        #
        # #### See Also
        # - `[]`
        # - `method_missing`
        #
        #: (*untyped, **untyped) ?{ (*untyped, **untyped) -> untyped } -> untyped
        def call(*args, **kwargs, &blk)
          return value.call(*args, **kwargs, &blk) if value.is_a?(Proc)

          key = args.first
          raise ArgumentError unless key.is_a?(Symbol)

          proc = value[key]
          raise NoMethodError, key unless proc.is_a?(Proc)

          proc = proc #: as untyped
          proc.call(*args, **kwargs, &blk)
        end

        # Handle dynamic method calls with intelligent dispatch
        #
        # This method implements a multi-level dispatch strategy:
        #
        # 1. **Value delegation**: If the value object responds to the method, delegates directly to it.
        #    This allows calling methods like `lines`, `length`, `upcase` on String values, or any
        #    method on the underlying object.
        #
        # 2. **Hash key access**: If the value is a Hash and contains the method name as a key,
        #    returns the value at that key. If the value is a Proc, calls it with the provided arguments.
        #
        # 3. **Fallback**: If neither condition is met, calls `super` to trigger standard Ruby behavior.
        #
        # #### See Also
        # - `respond_to_missing?`
        # - `[]`
        # - `call`
        #
        #: (Symbol, *untyped, **untyped) ?{ (*untyped, **untyped) -> untyped } -> untyped
        def method_missing(name, *args, **kwargs, &blk)
          return value.public_send(name, *args, **kwargs, &blk) if value.respond_to?(name, false)
          return super unless value.is_a?(Hash) && value.key?(name)

          if value[name].is_a?(Proc)
            proc = value[name] #: as untyped
            proc.call(*args, **kwargs, &blk)
          else
            value[name]
          end
        end

        # Check if a dynamic method should respond
        #
        # Returns `true` if any of the following conditions are met:
        # 1. The value object responds to the method
        # 2. The value is a Hash and contains the method name as a key
        # 3. The parent class would respond to the method
        #
        # #### See Also
        # - `method_missing`
        #
        #: (Symbol | String, ?bool) -> bool
        def respond_to_missing?(name, include_private = false)
          value.respond_to?(name, false) || value.is_a?(Hash) && value.key?(name) || super
        end
      end

      #: (Input) -> Output
      def execute(input)
        Output.new(input.value)
      end
    end
  end
end
