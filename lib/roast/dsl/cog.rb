# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # autoload :Store, "roast/dsl/cog/store"

      class << self
        #: () -> Symbol
        def method_name
          # TODO: nicer err handling
          raise "Cog class #{name} must implement method_name" if name.nil?

          class_name_parts = name.split("::")
          raise "Cog class #{name} must have a name" if class_name_parts.empty?

          last_part = class_name_parts.last
          raise "Cog class #{name} must have a name" if last_part.nil?

          last_part.downcase.to_sym
        end

        #: (*untyped) -> Roast::Cog
        def invoke(*args, **kwargs, &block)
          inst = new(*args, **kwargs, &block)
          # TODO: This is a bit gross.
          inst = Store.find(inst.id) || Store.insert(inst.id, inst)
          inst.on_invoke
          inst
        end
      end

      #: (Symbol) -> void
      def initialize(id)
        @id = id
      end

      # @final
      #: () -> Symbol
      def id
        "#{self.class.name}-#{@id}"
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
