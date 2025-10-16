# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Workflow
      class WorkflowError < Roast::Error; end
      class WorkflowNotPreparedError < WorkflowError; end
      class WorkflowAlreadyPreparedError < WorkflowError; end
      class WorkflowAlreadyStartedError < WorkflowError; end

      class << self
        #: (String) -> void
        def from_file(workflow_path)
          run!(File.read(workflow_path))
        end

        private

        #: (String) -> void
        def run!(workflow_definition)
          workflow = new
          workflow.prepare!(workflow_definition)
          workflow.start!
        end
      end

      #: () -> void
      def initialize
        @cogs = Cog::Store.new #: Cog::Store
        @cog_registry = Cog::Registry.new #: Cog::Registry
        @config_procs = [] #: Array[^() -> void]
        @execution_procs = { nil: [] } #: Hash[Symbol?, Array[^() -> void]]
        @config_manager = nil #: ConfigManager?
        @execution_manager = nil #: ExecutionManager?
      end

      #: (String) -> void
      def prepare!(workflow_definition)
        raise WorkflowAlreadyPreparedError if preparing? || prepared?

        @preparing = true
        extract_dsl_procs!(workflow_definition)
        @config_manager = ConfigManager.new(@cog_registry, @config_procs)
        @config_manager.prepare!
        @execution_manager = ExecutionManager.new(@cog_registry, @config_manager, @execution_procs[nil] || [])
        @execution_manager.prepare!

        @prepared = true
      end

      #: () -> void
      def start!
        raise WorkflowNotPreparedError unless @config_manager.present? && @execution_manager.present?
        raise WorkflowAlreadyStartedError if started? || completed?

        @started = true
        @execution_manager.run!
        @completed = true
      end

      #: () -> bool
      def preparing?
        @preparing ||= false
      end

      #: () -> bool
      def prepared?
        @prepared ||= false
      end

      #: () -> bool
      def started?
        @started ||= false
      end

      #: () -> bool
      def completed?
        @completed ||= false
      end

      #: { () [self: ConfigContext] -> void } -> void
      def config(&block)
        @config_procs << block
      end

      #: (?Symbol?) { () [self: ExecutionContext] -> void } -> void
      def execute(scope = nil, &block)
        (@execution_procs[scope] ||= []) << block
      end

      private

      # Evaluate the top-level workflow definition
      # This collects the procs passed to `config` and `execute` calls in the workflow definition,
      # but does not evaluate any of them individually yet.
      #: (String) -> void
      def extract_dsl_procs!(workflow_definition)
        instance_eval(workflow_definition)
      end
    end
  end
end
