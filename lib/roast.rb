# frozen_string_literal: true

require "raix"
require "thor"
require "roast/version"
require "roast/errors"
require "roast/tools"
require "roast/helpers"
require "roast/resources"
require "roast/workflow"
require "roast/initializers"

module Roast
  ROOT = File.expand_path("../..", __FILE__)

  class CLI < Thor
    desc "execute [WORKFLOW_CONFIGURATION_FILE] [FILES...]", "Run a configured workflow"
    option :concise, type: :boolean, aliases: "-c", desc: "Optional flag for use in output templates"
    option :output, type: :string, aliases: "-o", desc: "Save results to a file"
    option :verbose, type: :boolean, aliases: "-v", desc: "Show output from all steps as they are executed"
    option :target, type: :string, aliases: "-t", desc: "Override target files. Can be file path, glob pattern, or $(shell command)"
    option :replay, type: :string, aliases: "-r", desc: "Resume workflow from a specific step. Format: step_name or session_timestamp:step_name"
    option :pause, type: :string, aliases: "-p", desc: "Pause workflow after a specific step. Format: step_name"

    def execute(*paths)
      raise Thor::Error, "Workflow configuration file is required" if paths.empty?

      workflow_path, *files = paths
      expanded_workflow_path = File.expand_path(workflow_path)
      raise Thor::Error, "Expected a Roast workflow configuration file, got directory: #{expanded_workflow_path}" if File.directory?(expanded_workflow_path)

      Roast::Workflow::ConfigurationParser.new(expanded_workflow_path, files, options.transform_keys(&:to_sym)).begin!
    end

    desc "version", "Display the current version of Roast"
    def version
      puts "Roast version #{Roast::VERSION}"
    end

    class << self
      def exit_on_failure?
        true
      end
    end
  end
end
