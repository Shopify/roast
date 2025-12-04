# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles execution of conditional steps (if and unless)
    class ConditionalExecutor
      def initialize(workflow, context_path, state_manager, workflow_executor = nil)
        @workflow = workflow
        @context_path = context_path
        @state_manager = state_manager
        @workflow_executor = workflow_executor
      end

      def execute_conditional(conditional_config)
        Roast::Log.debug("Executing conditional step: #{conditional_config.inspect}")

        # Determine if this is an 'if' or 'unless' condition
        condition_expr = conditional_config["if"] || conditional_config["unless"]
        is_unless = conditional_config.key?("unless")
        then_steps = conditional_config["then"]

        # Verify required parameters
        raise WorkflowExecutor::ConfigurationError, "Missing condition in conditional configuration" unless condition_expr
        raise WorkflowExecutor::ConfigurationError, "Missing 'then' steps in conditional configuration" unless then_steps

        # Create and execute a ConditionalStep
        conditional_step = ConditionalStep.new(
          @workflow,
          config: conditional_config,
          name: "conditional_#{condition_expr.gsub(/[^a-zA-Z0-9_]/, "_")[0..20]}",
          context_path: @context_path,
          workflow_executor: @workflow_executor,
        )

        result = conditional_step.call

        # Store a marker in workflow output to indicate which branch was taken
        condition_key = is_unless ? "unless" : "if"
        step_name = "#{condition_key}_#{condition_expr.gsub(/[^a-zA-Z0-9_]/, "_")[0..30]}"
        @workflow.output[step_name] = result

        # Save state
        @state_manager.save_state(step_name, @workflow.output[step_name])

        result
      end
    end
  end
end
