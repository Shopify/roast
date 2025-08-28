# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Graph < Roast::DSL::Cog
        include Storable
        include Updatable

        #: () -> Proc?
        attr_reader :block

        #: (Symbol, Proc?) -> void
        def initialize(name, &block)
          @name = name
          @block = block
          @graph = Roast::Graph.new
        end

        # @override
        #: () -> void
        def on_invoke
          populate!(@graph)
        end

        # @override
        #: () -> String
        def store_id
          @name
        end

        # @override
        #: (Roast::DSL::Cogs::Graph) -> void
        def update(other)
          return if other.block.nil?

          other.populate!(@graph)
        end

        # Populates the provided graph in-place, with the definition of how to populate in the block
        #: (Roast::DSL::Cogs::Graph) -> void
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
