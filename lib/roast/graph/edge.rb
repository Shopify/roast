# typed: true
# frozen_string_literal: true

module Roast
  class Graph
    class Edge
      #: (Node) -> void
      attr_writer :join_node

      attr_reader :from_node, :to_node

      #: (Node, Node, ?proc: Proc?) -> void
      def initialize(from_node, to_node, proc: nil)
        @from_node = from_node
        @to_node = to_node
        @proc = proc # TODO: Shadowing proc builtin here
      end

      #: () -> String
      def to_s
        "#{@from_node} -> #{@to_node}"
      end
    end
  end
end
