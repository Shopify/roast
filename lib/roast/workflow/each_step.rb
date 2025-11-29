# typed: false
# frozen_string_literal: true

module Roast
  module Workflow
    # Executes steps for each item in a collection
    class EachStep < BaseIterationStep
      attr_reader :collection_expr, :variable_name

      def initialize(workflow, collection_expr:, variable_name:, steps:, **kwargs)
        super(workflow, steps: steps, **kwargs)
        @collection_expr = collection_expr
        @variable_name = variable_name
      end

      def call
        # Process the collection expression with appropriate type coercion
        collection = process_iteration_input(@collection_expr, workflow, coerce_to: :iterable)

        unless collection.respond_to?(:each)
          Roast::Log.error("Error: Collection '#{@collection_expr}' is not iterable")
          raise ArgumentError, "Collection '#{@collection_expr}' is not iterable"
        end

        results = []
        Roast::Log.info("Starting each loop over collection with #{collection.size} items")

        # Iterate over the collection
        collection.each_with_index do |item, index|
          Roast::Log.debug("Each loop iteration #{index + 1} with #{@variable_name}=#{item.inspect}")

          # Create a context with the current item as a variable
          define_iteration_variable(item)

          # Execute the nested steps
          step_results = execute_nested_steps(@steps, workflow)
          results << step_results

          # Save state after each iteration if the workflow supports it
          save_iteration_state(index, item) if workflow.respond_to?(:session_name) && workflow.session_name
        end

        Roast::Log.info("Each loop completed with #{collection.size} iterations")
        results
      end

      private

      # Keep for backward compatibility, deprecated
      def resolve_collection
        process_iteration_input(@collection_expr, workflow, coerce_to: :iterable)
      end

      def define_iteration_variable(value)
        # Set the variable in the workflow's context
        workflow.instance_variable_set("@#{@variable_name}", value)

        # Define a getter method for the variable if it doesn't exist
        var_name = @variable_name.to_sym
        unless workflow.respond_to?(var_name)
          workflow.singleton_class.class_eval do
            attr_reader(var_name)
          end
        end

        # Make the variable accessible in the output hash
        workflow.output[@variable_name] = value if workflow.respond_to?(:output)
      end

      def save_iteration_state(index, item)
        state_repository = StateRepositoryFactory.create(workflow.storage_type)

        # Save the current iteration state
        state_data = {
          step_name: name,
          iteration_index: index,
          current_item: item,
          output: workflow.respond_to?(:output) ? workflow.output.clone : {},
          transcript: workflow.respond_to?(:transcript) ? workflow.transcript.map(&:itself) : [],
        }

        state_repository.save_state(workflow, "#{name}_item_#{index}", state_data)
      rescue => e
        # Don't fail the workflow if state saving fails
        Roast::Log.warn("Warning: Failed to save iteration state: #{e.message}")
      end
    end
  end
end
