# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Execute < Command
      def invoke(args, name)
        options = parse_options(args, name)

        # Extract the workflow path and files from the remaining args (after option parsing)
        workflow_path, *files = args

        handle_error(StandardError.new("Workflow configuration file is required")) if workflow_path.nil?

        if options[:executor] == "dsl"
          puts "⚠️ WARNING: This is an experimental syntax and may break at any time. Don't depend on it."
          Roast::DSL::Executor.from_file(workflow_path)
        else
          expanded_workflow_path = if workflow_path.include?("workflow.yml")
            File.expand_path(workflow_path)
          else
            File.expand_path("roast/#{workflow_path}/workflow.yml")
          end

          handle_error(StandardError.new("Expected a Roast workflow configuration file, got directory: #{expanded_workflow_path}")) if File.directory?(expanded_workflow_path)

          Roast::Workflow::WorkflowRunner.new(expanded_workflow_path, files, options).begin!
        end
      rescue => e
        if options && options[:verbose]
          raise e
        else
          $stderr.puts e.message
        end
      end

      def help_message
        <<~HELP
          Execute a configured workflow

          Usage: roast execute [WORKFLOW_CONFIGURATION_FILE] [FILES...]

          Options:
            -c, --concise              Optional flag for use in output templates
            -o, --output FILE          Save results to a file
            -v, --verbose              Show output from all steps as they are executed
            -t, --target PATTERN       Override target files. Can be file path, glob pattern, or $(shell command)
            -r, --replay STEP          Resume workflow from a specific step. Format: step_name or session_timestamp:step_name
            -p, --pause STEP           Pause workflow after a specific step. Format: step_name
            -f, --file-storage         Use filesystem storage for sessions instead of SQLite
            --executor TYPE            Set workflow executor - experimental syntax (default: default)
        HELP
      end

      def configure_options(command_name, parser, options)
        options[:executor] = "default"

        parser.on("-c", "--concise") { options[:concise] = true }
        parser.on("-v", "--verbose") { options[:verbose] = true }
        parser.on("-f", "--file-storage") { options[:file_storage] = true }
        parser.on("-o", "--output FILE") { |file| options[:output] = file }
        parser.on("-t", "--target PATTERN") { |pattern| options[:target] = pattern }
        parser.on("-r", "--replay STEP") { |step| options[:replay] = step }
        parser.on("-p", "--pause STEP") { |step| options[:pause] = step }
        parser.on("--executor TYPE") { |type| options[:executor] = type || "default" }
      end
    end
  end
end
