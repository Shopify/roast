# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles output operations for workflows including saving final output and results
    class OutputHandler
      def save_final_output(workflow)
        return unless workflow.respond_to?(:session_name) && workflow.session_name && workflow.respond_to?(:final_output)

        begin
          final_output = workflow.final_output.to_s
          return if final_output.empty?

          state_repository = StateRepositoryFactory.create(workflow.storage_type)
          output_file = state_repository.save_final_output(workflow, final_output)
          Roast::Log.info("Final output saved to: #{output_file}") if output_file
        rescue => e
          # Don't fail if saving output fails
          Roast::Log.warn("Warning: Failed to save final output to session: #{e.message}")
        end
      end

      def write_results(workflow)
        if workflow.output_file
          File.write(workflow.output_file, workflow.final_output)
          Roast::Log.info("Results saved to #{workflow.output_file}")
        else
          Roast::Log.info("🔥🔥🔥 Final Output: 🔥🔥🔥")
          Roast::Log.info(workflow.final_output)
        end
      end
    end
  end
end
