# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class ExecutorError < Roast::Error; end
      class ExecutorAlreadyPreparedError < ExecutorError; end
      class ExecutorAlreadyCompletedError < ExecutorError; end

      class << self
        def from_file(workflow_path)
          run!(File.read(workflow_path))
        end

        private

        def run!(workflow_definition)
          executor = new
          executor.prepare!(workflow_definition)
          executor.start!
        end
      end

      def prepare!(input)
        # You can only initialize an executor once.
        raise ExecutorAlreadyPreparedError if @prepared

        extract_dsl_procs(input)
        @cogs = Cog::Store.new
        @cog_stack = Cog::Stack.new

        @config_context = ConfigContext.new(@cogs, @config_proc)
        @config_context.prepare!
        @execution_context = WorkflowExecutionContext.new(@cogs, @cog_stack, @execution_proc)
        @execution_context.prepare!

        @prepared = true
      end

      def start!
        # Now we run the cogs!
        # You can only do this once, executors are not reusable to avoid state pollution
        raise ExecutorAlreadyCompletedError if @completed

        @cog_stack.map do |name, cog|
          cog.run!(
            @config_context.fetch_merged_config(cog.class, name.to_sym),
            @execution_context.cog_execution_context,
          )
        end

        @completed = true
      end

      def prepared?
        @prepared ||= false
      end

      def completed?
        @completed ||= false
      end

      #: { () [self: ConfigContext] -> void} -> void
      def config(&block)
        @config_proc = block
      end

      #: { () [self: WorkflowExecutionContext] -> void} -> void
      def execute(&block)
        @execution_proc = block
      end

      # Separating the instance evals ensures that we can reuse the same cog method
      # names between config and execute, while have the backing objects be completely
      # different. This means we have an enforced separation between configuring and running.
      def extract_dsl_procs(input)
        instance_eval(input)
      end
    end
  end
end
