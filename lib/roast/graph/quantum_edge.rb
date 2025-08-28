# typed: true
# frozen_string_literal: true

module Roast
  class Graph
    class QuantumEdge
      #: (Roast::Graph::Node, Proc) -> void
      def initialize(from_node, to_proc)
        @from_node = from_node
        @to_proc = to_proc
      end

      #: (Hash[untyped, untyped], Hash[Symbol, Roast::Graph::Node]) -> Array[Roast::Graph::Edge]
      def collapse(state, nodes)
        to_node_names = @to_proc.call(state)
        to_node_names = to_node_names.is_a?(Array) ? to_node_names : [to_node_names]

        to_node_names.map do |to_node_name|
          to_node = nodes[to_node_name]
          raise Error, "No node found with name #{to_node_name.inspect}" if to_node.nil?

          Edge.new(@from_node, to_node)
        end
      end
    end
  end
end
