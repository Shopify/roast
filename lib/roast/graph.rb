# typed: true
# frozen_string_literal: true

module Roast
  class Graph
    class Error < StandardError; end
    class AddEdgeError < Error; end
    class EdgeTopologyError < Error; end

    #: (Symbol, Proc?) -> void
    def subgraph(name, &block)
      subgraph = Graph.new
      yield subgraph
      nodes[name] = Node.new(name, executable: subgraph)
    end

    #: (Symbol, Proc) -> void
    def node(name, &block)
      nodes[name] = Node.new(name, executable: block)
    end

    #: (from: Symbol | Array[Symbol], to: Symbol | Array[Symbol] | nil, Proc?) -> void
    def edge(from:, to: nil, &block)
      from_nodes = from.is_a?(Array) ? from.map { |from_node| nodes[from_node] } : [nodes[from]].compact
      to_nodes = to.is_a?(Array) ? to.map { |to_node| nodes[to_node] } : [nodes[to]].compact

      if from_nodes.empty?
        raise AddEdgeError, "Cannot create edge from #{from.inspect} to #{to.inspect} because #{from.inspect} does not exist"
      end

      if block.nil?
        if to_nodes.empty?
          raise AddEdgeError, "Cannot create edge from #{from.inspect} to #{to.inspect} because #{to.inspect} does not exist"
        end

        from_nodes.each do |from_node|
          to_nodes.each do |to_node|
            insert_edge(Edge.new(from_node, to_node))
          end
        end
      else
        from_nodes.each do |from_node|
          quantum_edges[from_node.name] = QuantumEdge.new(from_node, block)
        end
      end
    end

    #: (Hash?) -> void
    def execute(init_state = nil)
      return if nodes.empty?

      # HACK: Move the DONE node to the end of the nodes array.
      # In reality we should have a separate "ordered" representation of the nodes, and we store the
      # main thing as a set.
      nodes[:DONE] = nodes.delete(:DONE)

      self.state = init_state unless init_state.nil?

      current_nodes = [nodes.values.first]

      until current_nodes.any?(&:done?)
        if current_nodes.size == 1
          current_nodes.first.execute(state)
        else
          ThreadedExec.new(current_nodes, state).async_execute
        end

        current_nodes = find_next(current_nodes)
      end
    end

    private

    #: () -> Hash[Symbol, Node]
    def nodes
      @nodes ||= { START: Node.new(:START), DONE: Node.new(:DONE) }
    end

    #: () -> Hash[Symbol, Array[Edge]]
    def edges
      @edges ||= {}
    end

    #: () -> Hash[Symbol, Roast::DSL::Graph::QuantumEdge]
    def quantum_edges
      @quantum_edges ||= {}
    end

    #: () -> Hash
    def state
      @state ||= {}
    end

    #: (Hash) -> void
    def state=(new_state)
      raise Error, "State already set, cannot set it again" if !@state.nil? && !new_state.nil?

      @state = new_state
    end

    #: (Array[Node]) -> Array[Node]
    def find_next(current_nodes)
      raise Error, "Somehow got an empty array of nodes" if current_nodes.empty?

      collapse_quantum_edges(current_nodes)

      next_edges = if current_nodes.size == 1
        next_edges_for_node(current_nodes.first)
      elsif current_nodes.size > 1
        next_edges_for_nodes(current_nodes)
      end

      if next_edges.nil?
        raise EdgeTopologyError, "No next edges found for #{current_nodes.map(&:name).join(', ')}, please define edges for this node"
      end

      next_nodes = next_edges.map(&:to_node).uniq

      # If we're doing paralell nodes, we need to lookahead to ensuer we join back at the same node.
      if next_nodes.size > 1
        raise EdgeTopologyError, "Parallel execution many to many nodes is not supported" if current_nodes.size != 1

        collapse_quantum_edges(next_nodes)
        raise_unless_all_point_to_same_next_node?(next_nodes)
      end

      next_nodes
    end

    #: (Array[Node]) -> bool
    def raise_unless_all_point_to_same_next_node?(nodes)
      next_nodes = nodes.map { |node| edges_from(node) }.compact.flatten.map(&:to_node).uniq
      # TODO: Deal with when next_nodes here is empty, should be generic "if you define any edges, you must define them all"
      if next_nodes.size > 1
        Roast::Helpers::Logger.info("Next nodes: #{next_nodes.map(&:name).join(', ')}")
        raise EdgeTopologyError, "Parallel nodes #{nodes.map(&:name).join(', ')} have different next nodes: #{next_nodes.inspect}"
      end

      true
    end

    #: (Array[Node]) -> void
    def collapse_quantum_edges(current_nodes)
      curr_quantum_edges = current_nodes.map do |node|
        quantum_edges[node.name]
      end.compact

      return if curr_quantum_edges.empty?

      if curr_quantum_edges.size > 1
        raise EdgeTopologyError, <<~MANY_Q_EDGES
          Multiple quantum edges for nodes:
          Nodes: #{current_nodes.map(&:name).join(', ')}"
          Quantum Edges: #{quantum_edges.inspect}
        MANY_Q_EDGES
      end

      edges = curr_quantum_edges.map do |quantum_edge|
        quantum_edge.collapse(state)
      end

      edges.each do |edge|
        insert_edge(edge)
      end
    end

    #: (Node) -> Array[Edge]
    def next_edges_for_node(current_node)
      next_edges = edges_from(current_node)
      # If the user never defined any edges, we'll just use the next node in the file.
      next_edges ||= [edge_from_next_loaded(current_node.name)] if edges.empty?
      next_edges
    end

    #: (Array[Node]) -> Array[Edge]
    def next_edges_for_nodes(current_nodes)
      maybe_next_edges = current_nodes.map { |node| edges_from(node) }.compact.flatten

      # Verify there are same number of edges as nodes.
      if maybe_next_edges.size != current_nodes.size
        raise EdgeTopologyError, <<~WRONG_NUM_EDGES
          Parallel nodes have different numbers of edges:
          Next Edges: #{maybe_next_edges}
          Parallel nodes: #{current_nodes.map(&:name).join(', ')}
        WRONG_NUM_EDGES
      end

      # Verify all the edges go to the same place.
      if maybe_next_edges.map(&:to_node).uniq!.size != 1
        # TODO: Present which edges are going to different places.
        raise EdgeTopologyError, <<~WRONG_NUM_EDGES
          Parallel nodes end up at different nodes:
          Next Edges: #{maybe_next_edges}
          Parallel nodes: #{current_nodes.map(&:name).join(', ')}
        WRONG_NUM_EDGES
      end

      maybe_next_edges
    end

    #: (Node) -> Array[Edge]?
    def edges_from(from_node)
      edges[from_node.name]
    end

    #: (Edge) -> void
    def insert_edge(edge)
      edges[edge.from_node.name] ||= []
      edges[edge.from_node.name] << edge
    end

    #: (Symbol) -> Edge?
    def edge_from_next_loaded(current_node_name)
      next_node = next_loaded_node(current_node_name)
      return nil if next_node.nil?

      Edge.new(nodes[current_node_name], next_node)
    end

    #: (Symbol) -> Node?
    def next_loaded_node(current_node_name)
      current_index = nodes.keys.index(current_node_name)
      next_index = (current_index + 1)
      nodes.values[next_index]
    end
  end
end
