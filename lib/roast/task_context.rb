# typed: true
# frozen_string_literal: true

module Roast
  module TaskContext
    extend self

    class PathElement
      #: Cog?
      attr_reader :cog

      #: ExecutionManager?
      attr_reader :execution_manager

      #: (?cog: Cog?, ?execution_manager: ExecutionManager?) -> void
      def initialize(cog: nil, execution_manager: nil)
        @cog = cog
        @execution_manager = execution_manager
      end
    end

    #: () -> Array[PathElement]
    def path
      Fiber[:path]&.deep_dup || []
    end

    #: (Cog) -> Array[PathElement]
    def begin_cog(cog)
      begin_element(PathElement.new(cog:))
    end

    #: (ExecutionManager) -> Array[PathElement]
    def begin_execution_manager(execution_manager)
      begin_element(PathElement.new(execution_manager:))
    end

    #: () -> [PathElement, Array[PathElement]]
    def end
      Event << { end: Fiber[:path]&.last }
      el = Fiber[:path]&.pop
      [el, path]
    end

    private

    #: (PathElement) -> Array[PathElement]
    def begin_element(element)
      Fiber[:path] = (Fiber[:path] || []) + [element]
      Event << { begin: element }
      path
    end
  end
end
