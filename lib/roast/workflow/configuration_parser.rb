# frozen_string_literal: true

module Roast
  module Workflow
    class ConfigurationParser
      extend Forwardable

      attr_reader :configuration, :options, :files, :current_workflow

      def_delegator :current_workflow, :output

      def initialize(workflow_path, files = [], options = {})
        @configuration = Configuration.new(workflow_path, options)
        @options = options
        @files = files

        # Initialize workflow dependencies
        initializer = WorkflowInitializer.new(@configuration)
        initializer.setup

        @workflow_runner = WorkflowRunner.new(@configuration, @options)
      end

      def begin!
        start_time = Time.now
        $stderr.puts "Starting workflow..."
        $stderr.puts "Workflow: #{configuration.workflow_path}"
        $stderr.puts "Options: #{options}"

        ActiveSupport::Notifications.instrument("roast.workflow.start", {
          workflow_path: configuration.workflow_path,
          options: options,
          name: configuration.basename,
        })

        if files.any?
          @workflow_runner.run_for_files(files)
        elsif configuration.has_target?
          @workflow_runner.run_for_targets
        else
          @workflow_runner.run_targetless
        end
      ensure
        execution_time = Time.now - start_time

        ActiveSupport::Notifications.instrument("roast.workflow.complete", {
          workflow_path: configuration.workflow_path,
          success: !$ERROR_INFO,
          execution_time: execution_time,
        })
      end
    end
  end
end
