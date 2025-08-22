# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class List < Command
      def invoke(_args, _name)
        roast_dir = File.join(Dir.pwd, "roast")

        unless File.directory?(roast_dir)
          handle_error(StandardError.new("No roast/ directory found in current path"))
        end

        workflow_files = Dir.glob(File.join(roast_dir, "**/workflow.yml")).sort

        if workflow_files.empty?
          handle_error(StandardError.new("No workflow.yml files found in roast/ directory"))
        end

        puts "Available workflows:"
        puts

        workflow_files.each do |file|
          workflow_name = File.dirname(file.sub("#{roast_dir}/", ""))
          puts "  #{workflow_name} (from project)"
        end

        puts
        puts "Run a workflow with: roast execute <workflow_name>"
      end

      def help_message
        <<~HELP
          List workflows visible to Roast and their source

          Usage: roast list
        HELP
      end
    end
  end
end
