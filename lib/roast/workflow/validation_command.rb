# typed: true
# frozen_string_literal: true

module Roast
  module Workflow
    # Handles the validation command logic for the CLI
    class ValidationCommand
      def initialize(options = {})
        @options = options
      end

      def execute(workflow_path = nil)
        workflow_files = resolve_workflow_files(workflow_path)
        validate_workflows(workflow_files)
      end

      private

      def resolve_workflow_files(workflow_path)
        if workflow_path.nil?
          find_all_workflows
        else
          [expand_workflow_path(workflow_path)]
        end
      end

      def find_all_workflows
        roast_dir = File.join(Dir.pwd, "roast")
        unless File.directory?(roast_dir)
          raise CLI::Kit::Abort, "No roast/ directory found in current path"
        end

        workflow_files = Dir.glob(File.join(roast_dir, "**/workflow.yml")).sort
        if workflow_files.empty?
          raise CLI::Kit::Abort, "No workflow.yml files found in roast/ directory"
        end

        workflow_files
      end

      def expand_workflow_path(workflow_path)
        expanded_path = if workflow_path.end_with?(".yml", ".yaml") || workflow_path.include?("/")
          File.expand_path(workflow_path)
        else
          File.expand_path("roast/#{workflow_path}/workflow.yml")
        end

        unless File.exist?(expanded_path)
          raise CLI::Kit::Abort, "Workflow file not found: #{expanded_path}"
        end

        expanded_path
      end

      def validate_workflows(workflow_files)
        results = ValidationResults.new

        validate_multiple_workflows_display(workflow_files, results)

        display_summary(results)
        exit_if_needed(results)
      end

      def validate_multiple_workflows_display(workflow_files, results)
        ::CLI::UI::Frame.open("Validating #{workflow_files.size} workflow(s)") do
          validate_each_workflow(workflow_files, results)
        end
      end

      def validate_each_workflow(workflow_files, results)
        workflow_files.each do |workflow_path|
          workflow_name = extract_workflow_name(workflow_path)
          validator = create_validator(workflow_path)
          # Ensure validation is performed to populate errors/warnings
          is_valid = validator.valid?
          results.add_result(workflow_path, validator)

          display_workflow_result(workflow_name, validator, is_valid)
        end
      end

      def display_workflow_result(workflow_name, validator, is_valid)
        if is_valid
          if validator.warnings.empty?
            CLI::UI.puts("{{green:✓}} {{bold:#{workflow_name}}}")
          else
            CLI::UI.puts("{{green:✓}} {{bold:#{workflow_name}}} ({{yellow:#{validator.warnings.size} warning(s)}})")
          end
        else
          CLI::UI.puts("{{red:✗}} {{bold:#{workflow_name}}} ({{red:#{validator.errors.size} error(s)}})")
        end
      end

      def create_validator(workflow_path)
        yaml_content = File.read(workflow_path)
        Validators::ValidationOrchestrator.new(yaml_content, workflow_path)
      end

      def extract_workflow_name(workflow_path)
        workflow_path.sub("#{Dir.pwd}/roast/", "").sub("/workflow.yml", "")
      end

      def display_summary(results)
        puts

        if results.total_errors == 0 && results.total_warnings == 0
          CLI::UI.puts("{{green:All workflows are valid!}}")
        elsif results.total_errors == 0
          CLI::UI.puts("{{green:All workflows are valid}} with {{yellow:#{results.total_warnings} total warning(s)}}")
          display_all_warnings(results)
        else
          CLI::UI.puts("{{red:Validation failed:}} #{results.total_errors} error(s), #{results.total_warnings} warning(s)")
          display_all_errors(results)
          display_all_warnings(results) if results.total_warnings > 0
        end
      end

      def exit_if_needed(results)
        if results.total_errors > 0
          exit(1)
        elsif results.total_warnings > 0 && @options[:strict]
          exit(1)
        end
      end

      def display_errors(errors)
        ::CLI::UI::Frame.open("Errors", color: :red) do
          errors.each do |error|
            puts ::CLI::UI.fmt("{{red:• #{error[:message]}}}")
            puts ::CLI::UI.fmt("  {{gray:→ #{error[:suggestion]}}}") if error[:suggestion]
            puts
          end
        end
      end

      def display_warnings(warnings)
        ::CLI::UI::Frame.open("Warnings", color: :yellow) do
          warnings.each do |warning|
            puts ::CLI::UI.fmt("{{yellow:• #{warning[:message]}}}")
            puts ::CLI::UI.fmt("  {{gray:→ #{warning[:suggestion]}}}") if warning[:suggestion]
            puts
          end
        end
      end

      def display_all_errors(results)
        results.results_with_errors.each do |result|
          workflow_name = extract_workflow_name(result[:path])
          ::CLI::UI::Frame.open("Errors in #{workflow_name}", color: :red) do
            result[:validator].errors.each do |error|
              puts ::CLI::UI.fmt("{{red:• #{error[:message]}}}")
              puts ::CLI::UI.fmt("  {{gray:→ #{error[:suggestion]}}}") if error[:suggestion]
              puts
            end
          end
        end
      end

      def display_all_warnings(results)
        results.results_with_warnings.each do |result|
          workflow_name = extract_workflow_name(result[:path])
          ::CLI::UI::Frame.open("Warnings in #{workflow_name}", color: :yellow) do
            result[:validator].warnings.each do |warning|
              puts ::CLI::UI.fmt("{{yellow:• #{warning[:message]}}}")
              puts ::CLI::UI.fmt("  {{gray:→ #{warning[:suggestion]}}}") if warning[:suggestion]
              puts
            end
          end
        end
      end

      # Tracks validation results across multiple workflows
      class ValidationResults
        attr_reader :total_errors, :total_warnings

        def initialize
          @total_errors = 0
          @total_warnings = 0
          @results = []
        end

        def add_result(workflow_path, validator)
          @results << { path: workflow_path, validator: validator }
          @total_errors += validator.errors.size
          @total_warnings += validator.warnings.size
        end

        def results_with_errors
          @results.select { |result| result[:validator].errors.any? }
        end

        def results_with_warnings
          @results.select { |result| result[:validator].warnings.any? }
        end
      end
    end
  end
end
