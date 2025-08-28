# frozen_string_literal: true
# typed: true

module Roast
  class Graph
    class QuantumEdge
      #: (Roast::Graph::Node, Proc) -> void
      def initialize(from_node, to_proc)
        @from_node = from_node
        @to_proc = to_proc
      end

      #: (Hash) -> Array[Roast::Graph::Edge]
      def collapse(state)
        to_nodes = to_proc.call(state)
        to_nodes = to_nodes.is_a?(Array) ? to_nodes : [to_nodes]

        to_nodes.map do |to_node|
          Edge.new(@from_node, to_node)
        end
      end
    end
  end
end
