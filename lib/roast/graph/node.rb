# typed: true
# frozen_string_literal: true

module Roast
  class Graph
    class Node
      # class InvalidExecutableError < Roast::Error; end

      attr_reader :name, :executable

      #: (Symbol, ?executable: Proc | Graph | nil) -> void
      def initialize(name, executable: nil)
        @name = name
        @executable = executable
      end

      #: () -> T::Boolean
      def subgraph?
        @executable.is_a?(Graph)
      end

      #: () -> T::Boolean
      def done?
        @name == :DONE
      end

      #: (Hash) -> void
      def execute(state)
        return if @executable.nil?

        executable = @executable
        if executable.is_a?(Proc)
          executable.call(state)
        elsif executable.is_a?(Graph)
          executable.execute(state)
        end
      end
    end
  end
end
