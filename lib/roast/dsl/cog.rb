# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      autoload :Store, "roast/dsl/cog/store"

      class << self
        #: () -> Symbol
        def method_name
          # TODO: nicer err handling
          raise "Cog class #{name} must implement method_name" if name.nil?

          class_name_parts = T.must(name).split("::")
          raise "Cog class #{name} must have a name" if class_name_parts.empty?

          last_part = class_name_parts.last
          raise "Cog class #{name} must have a name" if last_part.nil?

          last_part.downcase.to_sym
        end

        #: (*untyped, **untyped) { (*untyped) -> void } -> Roast::DSL::Cog
        def invoke(*args, **kwargs, &block)
          # TODO: This should go away with the block interface, I hope.
          inst = self #: as untyped # rubocop:disable Style/RedundantSelf
            .new(*args, **kwargs, &block)

          # Retrieve existing if possible
          found_inst = inst.find if inst.class.include?(Storable)

          # If there is an existing one, and its updatable, update it
          unless found_inst.nil?
            found_inst.update(inst) if found_inst.class.include?(Updatable)
            inst = found_inst
          end

          # Store it if we can
          inst.store if inst.class.include?(Storable)

          inst.on_invoke
          inst.invoke_return
        end
      end

      # TODO: This is slightly gross being untyped
      #: () -> untyped
      def invoke_return
        self # Optional override
      end

      # TODO: Probably some sort of Runnable module we can include.
      # TODO: Support custom output types.
      #: () -> String
      def output
        raise NotImplementedError, "Subclass must implement output"
      end

      #: () -> void
      def on_invoke
        # noop, override in subclass if needed.
      end
    end
  end
end
