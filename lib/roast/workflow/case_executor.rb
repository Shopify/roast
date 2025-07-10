# frozen_string_literal: true

module Roast
  module Workflow
    # Handles execution of case/when/else steps
    class CaseExecutor
      def initialize(workflow, context_path, state_manager, workflow_executor = nil)
        @workflow = workflow
        @context_path = context_path
        @state_manager = state_manager
        @workflow_executor = workflow_executor
      end

      def execute_case(case_config)
        $stderr.puts "🔀 Executing case step: #{case_config.inspect}"

        # Extract case expression
        case_expr = case_config["case"]
        when_clauses = case_config["when"]
        case_config["else"]

        # Verify required parameters
        raise WorkflowExecutor::ConfigurationError, "Missing 'case' expression in case configuration" unless case_expr
        raise WorkflowExecutor::ConfigurationError, "Missing 'when' clauses in case configuration" unless when_clauses

        # Create and execute a CaseStep
        case_step = CaseStep.new(
          @workflow,
          config: case_config,
          name: "case_#{case_expr.to_s.gsub(/[^a-zA-Z0-9_]/, "_")[0..30]}",
          context_path: @context_path,
          workflow_executor: @workflow_executor,
        )

        result = case_step.call

        # Store the result in workflow output
        step_name = "case_#{case_expr.to_s.gsub(/[^a-zA-Z0-9_]/, "_")[0..30]}"
        @workflow.output[step_name] = result

        # Save state
        @state_manager.save_state(step_name, @workflow.output[step_name])

        result
      end
    end
  end
end
