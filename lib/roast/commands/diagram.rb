# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Diagram < Command
      def invoke(args, name)
        workflow_file = args.first
        handle_error(StandardError.new("Workflow file is required")) if workflow_file.nil?

        options = parse_options(args[1..], name)

        unless File.exist?(workflow_file)
          handle_error(StandardError.new("Workflow file not found: #{workflow_file}"))
        end

        workflow = Workflow::Configuration.new(workflow_file)
        generator = WorkflowDiagramGenerator.new(workflow, workflow_file)
        output_path = generator.generate(options[:output])

        CLI::UI.puts("{{success:✓}} Diagram generated: #{output_path}")
      rescue StandardError => e
        handle_error(e, "Error generating diagram: #{e.message}")
      end

      def help_message
        <<~HELP
          Generate a visual diagram of a workflow

          Usage: roast diagram WORKFLOW_FILE

          Options:
            -o, --output FILE          Output file path (defaults to workflow_name_diagram.png)
        HELP
      end

      def configure_options(command_name, parser, options)
        parser.on("-o", "--output FILE") { |file| options[:output] = file }
      end
    end
  end
end
