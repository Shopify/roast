# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class WorkflowParams
      #: Array[String]
      attr_reader :targets

      #: Array[Symbol]
      attr_reader :args

      #: Hash[Symbol, String]
      attr_reader :kwargs

      #: (Array[String], Array[Symbol], Hash[Symbol, String]) -> void
      def initialize(targets, args, kwargs)
        @targets = targets
        @args = args
        @kwargs = kwargs
      end
    end
  end
end
