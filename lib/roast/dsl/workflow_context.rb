# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class WorkflowContext
      #: WorkflowParams
      attr_reader :params

      #: String
      attr_reader :tmpdir

      #: (params: WorkflowParams, tmpdir: String) -> void
      def initialize(params:, tmpdir:)
        @params = params
        @tmpdir = tmpdir
      end
    end
  end
end
