# typed: true
# frozen_string_literal: true

module Roast
  class WorkflowContext
    #: WorkflowParams
    attr_reader :params

    #: String
    attr_reader :tmpdir

    #: Pathname
    attr_reader :workflow_dir

    #: (params: WorkflowParams, tmpdir: String, workflow_dir: Pathname) -> void
    def initialize(params:, tmpdir:, workflow_dir:)
      @params = params
      @tmpdir = tmpdir
      @workflow_dir = workflow_dir
    end
  end
end
