# typed: true
# frozen_string_literal: true

module Roast
  # @requires_ancestor: Kernel
  module WorkflowParamAccessors
    private

    #: () -> String
    def target!
      raise ArgumentError, "expected exactly one target" unless @workflow_context.params.targets.length == 1

      @workflow_context.params.targets.first #: as String
    end

    #: () -> Array[String]
    def targets
      @workflow_context.params.targets.dup
    end

    #: (Symbol) -> bool
    def arg?(value)
      @workflow_context.params.args.include?(value)
    end

    #: () -> Array[Symbol]
    def args
      @workflow_context.params.args.dup
    end

    #: (Symbol) -> String?
    def kwarg(key)
      @workflow_context.params.kwargs[key]
    end

    #: (Symbol) -> String
    def kwarg!(key)
      raise ArgumentError, "expected keyword argument '#{key}' to be present" unless @workflow_context.params.kwargs.include?(key)

      @workflow_context.params.kwargs[key] #: as String
    end

    #: (Symbol) -> bool
    def kwarg?(key)
      @workflow_context.params.kwargs.include?(key)
    end

    #: () -> Hash[Symbol, String]
    def kwargs
      @workflow_context.params.kwargs.dup
    end
  end
end
