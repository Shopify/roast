# frozen_string_literal: true

module Roast
  module Workflow
    # Handles running workflows for files/targets and orchestrating execution
    class WorkflowRunner
      def initialize(configuration, options = {})
        @configuration = configuration
        @options = options
        @output_handler = OutputHandler.new
        @execution_context = WorkflowExecutionContext.new
      end

      def run_for_files(files)
        if @configuration.has_target?
          $stderr.puts "⚠️ WARNING: Ignoring target parameter because files were provided: #{@configuration.target}"
        end

        # Execute pre-processing steps once before any targets
        if @configuration.pre_processing.any?
          $stderr.puts "🔧 Running pre-processing steps..."
          run_pre_processing
        end

        # Execute main workflow for each file
        files.each do |file|
          $stderr.puts "🗳️ Running workflow for file: #{file}"
          run_single_workflow(file.strip)
        end

        # Execute post-processing steps once after all targets
        if @configuration.post_processing.any?
          $stderr.puts "🧹 Running post-processing steps..."
          run_post_processing
        end
      end

      def run_for_targets
        # Split targets by line and clean up
        target_lines = @configuration.target.lines.map(&:strip).reject(&:empty?)

        # Execute pre-processing steps once before any targets
        if @configuration.pre_processing.any?
          $stderr.puts "🔧 Running pre-processing steps..."
          run_pre_processing
        end

        # Execute main workflow for each target
        target_lines.each do |file|
          $stderr.puts "🗳️ Running workflow for file: #{file}"
          run_single_workflow(file)
        end

        # Execute post-processing steps once after all targets
        if @configuration.post_processing.any?
          $stderr.puts "🧹 Running post-processing steps..."
          run_post_processing
        end
      end

      def run_targetless
        $stderr.puts "🎯 Running targetless workflow"

        # Execute pre-processing steps
        if @configuration.pre_processing.any?
          $stderr.puts "🔧 Running pre-processing steps..."
          run_pre_processing
        end

        # Execute main workflow
        run_single_workflow(nil)

        # Execute post-processing steps
        if @configuration.post_processing.any?
          $stderr.puts "🧹 Running post-processing steps..."
          run_post_processing
        end
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
        # Pass pre-processing data to target workflows
        # Flatten the structure to remove the 'output' intermediary
        pre_processing_data = @execution_context.pre_processing_output.raw_output.merge(
          final_output: @execution_context.pre_processing_output.final_output,
        )
        workflow = create_workflow(file, pre_processing_data: pre_processing_data)
        execute_workflow(workflow)

        # Store workflow output in execution context
        @execution_context.add_target_output(file, workflow.output_manager)
      end

      def run_pre_processing
        # Create a workflow for pre-processing (no specific file target)
        workflow = create_workflow(nil)

        # Execute pre-processing steps
        executor = WorkflowExecutor.new(workflow, @configuration.config_hash, @configuration.context_path, phase: :pre_processing)
        executor.execute_steps(@configuration.pre_processing)

        # Store pre-processing output in execution context
        @execution_context.pre_processing_output.output = workflow.output_manager.raw_output
        @execution_context.pre_processing_output.final_output = workflow.output_manager.final_output
      end

      def run_post_processing
        # Create a workflow for post-processing with access to all results
        workflow = create_workflow(nil)

        # Pass execution context data to post-processing workflow
        # Make pre_processing available as a top-level DotNotationHash with flattened structure
        pre_processing_data = @execution_context.pre_processing_output.raw_output.merge(
          final_output: @execution_context.pre_processing_output.final_output,
        )
        workflow.instance_variable_set(:@pre_processing, DotAccessHash.new(pre_processing_data))
        workflow.define_singleton_method(:pre_processing) { @pre_processing }

        # Keep targets in output for now
        workflow.output[:targets] = @execution_context.target_outputs.transform_values(&:to_h)

        # Execute post-processing steps
        executor = WorkflowExecutor.new(workflow, @configuration.config_hash, @configuration.context_path, phase: :post_processing)
        executor.execute_steps(@configuration.post_processing)

        # Apply output.txt template if it exists
        apply_post_processing_template(workflow)

        # Save post-processing outputs
        @output_handler.save_final_output(workflow)
        @output_handler.write_results(workflow)
      end

      def create_workflow(file, pre_processing_data: nil)
        BaseWorkflow.new(
          file,
          name: @configuration.basename,
          context_path: @configuration.context_path,
          resource: @configuration.resource,
          session_name: @configuration.name,
          workflow_configuration: @configuration,
          pre_processing_data:,
        ).tap do |workflow|
          workflow.output_file = @options[:output] if @options[:output].present?
          workflow.verbose = @options[:verbose] if @options[:verbose].present?
          workflow.concise = @options[:concise] if @options[:concise].present?
          workflow.pause_step_name = @options[:pause] if @options[:pause].present?
          # Set storage type based on CLI option (default is SQLite unless --file-storage is used)
          workflow.storage_type = @options[:file_storage] ? "file" : nil
          # Set model from configuration with fallback to default
          workflow.model = @configuration.model || StepLoader::DEFAULT_MODEL
          # Set context management configuration
          workflow.context_management_config = @configuration.context_management
        end
      end

      def apply_post_processing_template(workflow)
        # Check for output.txt template in post_processing directory
        template_path = File.join(@configuration.context_path, "post_processing", "output.txt")
        return unless File.exist?(template_path)

        # Prepare data for template
        template_data = {
          pre_processing: DotAccessHash.new(@execution_context.pre_processing_output.to_h),
          targets: @execution_context.target_outputs.transform_values { |v| DotAccessHash.new(v.to_h) },
          output: DotAccessHash.new(workflow.output_manager.raw_output),
          final_output: workflow.final_output,
        }

        # Create binding for ERB template with access to template data
        template_binding = binding
        template_data.each do |key, value|
          template_binding.local_variable_set(key, value)
        end

        # Apply template and append to final output
        template_content = File.read(template_path)
        rendered_output = ERB.new(template_content, trim_mode: "-").result(template_binding)
        workflow.append_to_final_output(rendered_output)
      rescue => e
        $stderr.puts "Warning: Failed to apply post-processing output template: #{e.message}"
      end
    end
  end
end
