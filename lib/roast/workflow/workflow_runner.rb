# frozen_string_literal: true

require "active_support/notifications"
require "roast/workflow/replay_handler"
require "roast/workflow/workflow_executor"
require "roast/workflow/output_handler"
require "roast/workflow/base_workflow"

module Roast
  module Workflow
    # Handles running workflows for files/targets and orchestrating execution
    class WorkflowRunner
      def initialize(configuration, options = {})
        @configuration = configuration
        @options = options
        @output_handler = OutputHandler.new
      end

      def run_for_files(files)
        if @configuration.has_target?
          $stderr.puts "WARNING: Ignoring target parameter because files were provided: #{@configuration.target}"
        end

        files.each do |file|
          $stderr.puts "Running workflow for file: #{file}"
          run_single_workflow(file.strip)
        end
      end

      def run_for_targets
        @configuration.target.lines.each do |file|
          $stderr.puts "Running workflow for file: #{file.strip}"
          run_single_workflow(file.strip)
        end
      end

      def run_targetless
        $stderr.puts "Running targetless workflow"
        run_single_workflow(nil)
      end

      # Public for backward compatibility with tests
      def execute_workflow(workflow)
        steps = @configuration.steps

        # Handle replay option
        if @options[:replay]
          replay_handler = ReplayHandler.new(workflow)
          steps = replay_handler.process_replay(steps, @options[:replay])
        end

        # Execute the steps
        executor = WorkflowExecutor.new(workflow, @configuration.config_hash, @configuration.context_path)
        executor.execute_steps(steps)

        $stderr.puts "🔥🔥🔥 ROAST COMPLETE! 🔥🔥🔥"

        # Save outputs
        @output_handler.save_final_output(workflow)
        @output_handler.write_results(workflow)
      end

      private

      def run_single_workflow(file)
        workflow = create_workflow(file)
        execute_workflow(workflow)
      end

      def create_workflow(file)
        BaseWorkflow.new(
          file,
          name: @configuration.basename,
          context_path: @configuration.context_path,
          resource: resource_for_workflow(file),
          session_name: @configuration.name,
          configuration: @configuration,
        ).tap do |workflow|
          workflow.output_file = @options[:output] if @options[:output].present?
          workflow.verbose = @options[:verbose] if @options[:verbose].present?
          workflow.concise = @options[:concise] if @options[:concise].present?
          workflow.pause_step_name = @options[:pause] if @options[:pause].present?
        end
      end

      def resource_for_workflow(file)
        # When running for specific files, let BaseWorkflow create the resource from the file
        # When running for targets or targetless, use the configuration's resource
        file ? nil : @configuration.resource
      end
    end
  end
end
