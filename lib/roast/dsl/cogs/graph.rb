# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Graph < Roast::DSL::Cog
        #: (Symbol, Proc?) -> void
        def initialize(name, &block)
          super(name)
          @name = name
          @block = block
          @graph = Roast::Graph.new(name, &block)
        end

        #: () -> void
        def on_invoke
          @graph.execute
        end

        # TODO: Get args from the command line into the graph cog, to know when we shold generate viz.
        #: () -> void
        def generate_viz
          Roast::Log.puts Roast::Graph::Viz.new(Roast::Graph.current.nodes, Roast::Graph.current.edges).to_dot
        end
      end
    end
  end
end
