# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class ExecutorError < Roast::Error; end
      class ExecutorNotPreparedError < ExecutorError; end
      class ExecutorAlreadyPreparedError < ExecutorError; end
      class ExecutorAlreadyCompletedError < ExecutorError; end

      class << self
        #: (String) -> void
        def from_file(workflow_path)
          run!(File.read(workflow_path))
        end

        private

        #: (String) -> void
        def run!(workflow_definition)
          executor = new
          executor.prepare!(workflow_definition)
          executor.start!
        end
      end

      #: () -> void
      def initialize
        @cogs = Cog::Store.new #: Cog::Store
        @cog_stack = Cog::Stack.new #: Cog::Stack
        @config_context = nil #: ConfigContext?
        @execution_context = nil #: WorkflowExecutionContext?
      end

      #: (String) -> void
      def prepare!(workflow_definition)
        # You can only initialize an executor once.
        raise ExecutorAlreadyPreparedError if prepared?

        extract_dsl_procs!(workflow_definition)
        @config_context = ConfigContext.new(@cogs, @config_proc)
        @config_context.prepare!
        @execution_context = WorkflowExecutionContext.new(@cogs, @cog_stack, @execution_proc)
        @execution_context.prepare!

        @prepared = true
      end

      #: () -> void
      def start!
        # Now we run the cogs!
        # You can only do this once, executors are not reusable to avoid state pollution
        raise ExecutorNotPreparedError unless @config_context.present? && @execution_context.present?
        raise ExecutorAlreadyCompletedError if completed?

        @cog_stack.map do |name, cog|
          cog.run!(
            @config_context.fetch_merged_config(cog.class, name.to_sym),
            @execution_context.cog_execution_context,
          )
        end

        @completed = true
      end

      #: () -> bool
      def prepared?
        @prepared ||= false
      end

      #: () -> bool
      def completed?
        @completed ||= false
      end

      #: { () [self: ConfigContext] -> void } -> ^() -> void
      def config(&block)
        @config_proc = block
      end

      #: { () [self: WorkflowExecutionContext] -> void } -> void
      def execute(&block)
        @execution_proc = block
      end

      private

      # Separating the instance evals ensures that we can reuse the same cog method
      # names between config and execute, while have the backing objects be completely
      # different. This means we have an enforced separation between configuring and running.
      #: (String) -> void
      def extract_dsl_procs!(workflow_definition)
        instance_eval(workflow_definition)
      end
    end
  end
end
