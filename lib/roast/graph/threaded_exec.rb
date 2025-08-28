# frozen_string_literal: true
# typed: true

module Roast
  class Graph
    class ThreadedExec
      def initialize(nodes, og_state)
        @nodes = nodes
        @og_state = og_state
      end

      #: () -> Hash
      def async_execute
        states = threaded_execute(@nodes, @og_state)
        merge_states!(@og_state, states)
      end

      # Returns a hash of the new states for each node.
      #: (Array[Node]) -> Hash[Symbol, Hash]
      def threaded_execute(nodes, og_state)
        states = {}
        threads = nodes.map do |current_node|
          states[current_node.name] = og_state.dup
          Thread.new do
            current_node.execute(states[current_node.name])
          end
        end

        threads.map(&:value)

        states
      end

      #: (Hash, Hash) -> void
      def merge_states!(orig_state, new_states)
        orig_state.merge!(merge_new_states(orig_state, new_states))
      end

      # We merge all the new states together first so we can catch any keys that were modified by multiple threads.
      #: (Hash, Hash[Symbol, Hash]) -> Hash
      def merge_new_states(orig_state, new_states)
        # We only care about what the threads have changes from the original state.
        changed_states = changed_states(orig_state, new_states)

        # Grab some entry to be the one we merge all the other changes into.
        base_node_name, base_changed_state = changed_states.shift

        changed_states.each do |node_name, changed_state|
          base_changed_state.merge!(changed_state) do |key, old_value, new_value|
            raise_state_conflict(key, old_value, new_value, [base_node_name, node_name])
          end
        end

        base_changed_state
      end

      #: (Hash, Hash[Symbol, Hash]) -> Hash[Symbol, Hash]
      def changed_states(orig_state, new_states)
        new_states.transform_values do |new_state|
          changed_state_entries(orig_state, new_state)
        end
      end

      # Filter new states content to only include keys that were modified by the new states.
      #: (Hash, Hash) -> Hash
      def changed_state_entries(orig_state, new_state)
        new_state.reject do |key, value|
          orig_state[key] == value
        end
      end

      #: (Symbol, untyped, untyped, Array[Symbol]) -> void
      def raise_state_conflict(key, old_value, new_value, conflicting_nodes)
        raise StateConflictError, <<~CONFLICT.chomp
          Parallel nodes modified the same state key.
          Conflicting nodes: #{conflicting_nodes.join(', ')}
          Key: :#{key}
          Old value:
          #{old_value.inspect}
          New value:
          #{new_value.inspect}
        CONFLICT
      end
    end
  end
end
