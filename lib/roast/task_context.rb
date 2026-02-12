# typed: true
# frozen_string_literal: true

module Roast
  module TaskContext
    extend self

    #: () -> Array[Symbol | Integer]
    def path
      Fiber[:path]&.dup || []
    end

    #: (Symbol | Integer) -> Array[Symbol | Integer]
    def begin(id)
      Event << { begin: id }
      Fiber[:path] = (Fiber[:path] || []) + [id]
      path
    end

    #: () -> [Symbol | Integer, Array[Symbol | Integer]]
    def end
      id = Fiber[:path]&.pop
      Event << { end: id }
      [id, path]
    end
  end
end
