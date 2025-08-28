# frozen_string_literal: true
# typed: true

module Roast
  class Graph
    class Node
        # class InvalidExecutableError < Roast::Error; end

        attr_reader :name, :executable

        #: (Symbol, executable: Proc | Graph | nil) -> void
        def initialize(name, executable: nil)
          @name = name
          @executable = executable
        end

        #: () -> Boolean
        def subgraph?
          @executable.is_a?(Graph)
        end

        #: () -> Boolean
        def done?
          @name == :DONE
        end

        #: (Hash) -> void
        def execute(state)
          return if @executable.nil?

          if @executable.is_a?(Proc)
            @executable.call(state)
          elsif @executable.is_a?(Graph)
            @executable.execute(state)
          else
            # TODO: Roast::Error
            # raise InvalidExecutableError, <<~INVALID.chomp
            raise <<~INVALID.chomp
              Invalid executable for node #{@name}: #{@executable.class.name} - #{@executable.inspect}
            INVALID
          end
        end
    end
  end
end
