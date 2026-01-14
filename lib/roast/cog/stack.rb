# typed: true
# frozen_string_literal: true

module Roast
  class Cog
    class Stack
      delegate :each, :empty?, :last, :map, :push, :size, to: :@queue

      #: () -> void
      def initialize
        @queue = [] #: Array[Cog]
      end

      #: () -> Roast::Cog?
      def pop
        @queue.shift
      end
    end
  end
end
