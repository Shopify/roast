# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles execution of iteration steps (repeat and each)
    class IterationExecutor
      def initialize(workflow, context_path, state_manager, config_hash = {})
        @workflow = workflow
        @context_path = context_path
        @state_manager = state_manager
        @config_hash = config_hash
      end

      def execute_repeat(repeat_config)
        Roast::Log.debug("Executing repeat step: #{repeat_config.inspect}")

        # Extract parameters from the repeat configuration
        steps = repeat_config["steps"]
        until_condition = repeat_config["until"]
        max_iterations = repeat_config["max_iterations"] || BaseIterationStep::DEFAULT_MAX_ITERATIONS

        # Verify required parameters
        raise WorkflowExecutor::ConfigurationError, "Missing 'steps' in repeat configuration" unless steps
        raise WorkflowExecutor::ConfigurationError, "Missing 'until' condition in repeat configuration" unless until_condition

        # Create and execute a RepeatStep
        repeat_step = RepeatStep.new(
          @workflow,
          steps: steps,
          until_condition: until_condition,
          max_iterations: max_iterations,
          name: "repeat_#{@workflow.output.size}",
          context_path: @context_path,
          config_hash: @config_hash,
        )

        # Apply configuration if provided
        apply_step_configuration(repeat_step, repeat_config)

        results = repeat_step.call

        # Store results in workflow output
        step_name = "repeat_#{until_condition.gsub(/[^a-zA-Z0-9_]/, "_")}"
        @workflow.output[step_name] = results

        # Save state
        @state_manager.save_state(step_name, results)

        results
      end

      def execute_each(each_config)
        Roast::Log.debug("Executing each step: #{each_config.inspect}")

        # Extract parameters from the each configuration
        collection_expr = each_config["each"]
        variable_name = each_config["as"]
        steps = each_config["steps"]

        # Verify required parameters
        raise WorkflowExecutor::ConfigurationError, "Missing collection expression in each configuration" unless collection_expr
        raise WorkflowExecutor::ConfigurationError, "Missing 'as' variable name in each configuration" unless variable_name
        raise WorkflowExecutor::ConfigurationError, "Missing 'steps' in each configuration" unless steps

        # Create and execute an EachStep
        each_step = EachStep.new(
          @workflow,
          collection_expr: collection_expr,
          variable_name: variable_name,
          steps: steps,
          name: "each_#{variable_name}",
          context_path: @context_path,
          config_hash: @config_hash,
        )

        # Apply configuration if provided
        apply_step_configuration(each_step, each_config)

        results = each_step.call

        # Store results in workflow output
        step_name = "each_#{variable_name}"
        @workflow.output[step_name] = results

        # Save state
        @state_manager.save_state(step_name, results)

        results
      end

      private

      # Apply configuration settings to a step
      def apply_step_configuration(step, step_config)
        step.print_response = step_config["print_response"] if step_config.key?("print_response")
        step.json = step_config["json"] if step_config.key?("json")
        step.params = step_config["params"] if step_config.key?("params")
        step.model = step_config["model"] if step_config.key?("model")
        step.coerce_to = step_config["coerce_to"].to_sym if step_config.key?("coerce_to")
      end
    end
  end
end
