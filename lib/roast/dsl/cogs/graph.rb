# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Graph < Roast::DSL::Cog
        #: Proc
        attr_reader :block

        #: (Symbol) { (Cog::Input) -> untyped } -> void
        def initialize(name, &block)
          @name = name
          @block = block
          @graph = Roast::Graph.new
          super(name, block)
        end

        #: () -> void
        def on_invoke
          populate!(@graph)
        end

        #: () -> Symbol
        def store_id
          @name.to_sym
        end

        #: (Roast::DSL::Cog) -> void
        def update(other)
          return unless other.is_a?(Roast::DSL::Cogs::Graph)

          return if other.block.nil?

          other.populate!(@graph)
        end

        # Populates the provided graph in-place, with the definition of how to populate in the block
        #: (Cog::Input) -> void
        def populate!(graph)
          return if @block.nil?

          @block.call(graph)
        end

        #: () -> void
        def execute
          @graph.execute
        end
      end
    end
  end
end
