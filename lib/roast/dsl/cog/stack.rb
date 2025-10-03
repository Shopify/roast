# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class Stack
        delegate :map, :push, :size, :empty?, to: :@queue

        def initialize
          @queue = []
        end

        #: () -> Roast::DSL::Cog?
        def pop
          @queue.shift
        end
      end
    end
  end
end
