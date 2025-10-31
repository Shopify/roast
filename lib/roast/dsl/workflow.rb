# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Workflow
      class WorkflowError < Roast::Error; end
      class WorkflowNotPreparedError < WorkflowError; end
      class WorkflowAlreadyPreparedError < WorkflowError; end
      class WorkflowAlreadyStartedError < WorkflowError; end
      class InvalidCogReference < WorkflowError; end

      class << self
        #: (String, WorkflowParams) -> void
        def from_file(workflow_path, params)
          workflow = new(workflow_path, params)
          workflow.prepare!
          workflow.start!
        end
      end

      #: (String, WorkflowParams) -> void
      def initialize(workflow_path, workflow_params)
        @workflow_path = Pathname.new(workflow_path) #: Pathname
        @workflow_params = workflow_params
        @workflow_definition = File.read(workflow_path) #: String
        @cog_registry = Cog::Registry.new #: Cog::Registry
        @config_procs = [] #: Array[^() -> void]
        @execution_procs = { nil: [] } #: Hash[Symbol?, Array[^() -> void]]
        @config_manager = nil #: ConfigManager?
        @execution_manager = nil #: ExecutionManager?
      end

      #: () -> void
      def prepare!
        raise WorkflowAlreadyPreparedError if preparing? || prepared?

        @preparing = true
        extract_dsl_procs!
        @config_manager = ConfigManager.new(@cog_registry, @config_procs)
        @config_manager.prepare!
        @execution_manager = ExecutionManager.new(@cog_registry, @config_manager, @execution_procs, scope_value: @workflow_params)
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

      def use(cogs = [], from: nil)
        require from if from

        Array.wrap(cogs).each do |cog_name|
          path = @workflow_path.realdirpath.dirname.join("cogs/#{cog_name}")
          require path.to_s if from.nil?

          cog_class_name = cog_name.camelize
          raise InvalidCogReference, "Expected #{cog_class_name} class, not found in #{path}" unless Object.const_defined?(cog_class_name)

          cog_class = cog_class_name.constantize # rubocop:disable Sorbet/ConstantsFromStrings
          @cog_registry.use(cog_class)
        end
      end

      private

      # Evaluate the top-level workflow definition
      # This collects the procs passed to `config` and `execute` calls in the workflow definition,
      # but does not evaluate any of them individually yet.
      #: () -> void
      def extract_dsl_procs!
        instance_eval(@workflow_definition)
      end
    end
  end
end
