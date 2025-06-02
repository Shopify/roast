# frozen_string_literal: true

require "active_support"
require "active_support/cache"
require "active_support/notifications"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/module/delegation"
require "active_support/isolated_execution_state"
require "fileutils"
require "cli/ui"
require "raix"
require "thor"
require "roast/errors"
require "roast/helpers"
require "roast/initializers"
require "roast/resources"
require "roast/tools"
require "roast/version"
require "roast/workflow"

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

      expanded_workflow_path = if workflow_path.include?("workflow.yml")
        File.expand_path(workflow_path)
      else
        File.expand_path("roast/#{workflow_path}/workflow.yml")
      end

      raise Thor::Error, "Expected a Roast workflow configuration file, got directory: #{expanded_workflow_path}" if File.directory?(expanded_workflow_path)

      Roast::Workflow::ConfigurationParser.new(expanded_workflow_path, files, options.transform_keys(&:to_sym)).begin!
    end

    desc "version", "Display the current version of Roast"
    def version
      puts "Roast version #{Roast::VERSION}"
    end

    desc "init", "Initialize a new Roast workflow from an example"
    option :example, type: :string, aliases: "-e", desc: "Name of the example to use directly (skips picker)"
    def init
      if options[:example]
        copy_example(options[:example])
      else
        show_example_picker
      end
    end

    private

    def show_example_picker
      examples = available_examples

      if examples.empty?
        puts "No examples found!"
        return
      end

      puts "Select an option:"
      choices = ["Pick from examples", "New from prompt (beta)"]

      selected = run_picker(choices, "Select initialization method:")

      case selected
      when "Pick from examples"
        example_choice = run_picker(examples, "Select an example:")
        copy_example(example_choice) if example_choice
      when "New from prompt (beta)"
        create_from_prompt
      end
    end

    def available_examples
      examples_dir = File.join(Roast::ROOT, "examples")
      return [] unless File.directory?(examples_dir)

      Dir.entries(examples_dir)
        .select { |entry| File.directory?(File.join(examples_dir, entry)) && entry != "." && entry != ".." }
        .sort
    end

    def run_picker(options, prompt)
      return if options.empty?

      ::CLI::UI::Prompt.ask(prompt) do |handler|
        options.each { |option| handler.option(option) { |selection| selection } }
      end
    end

    def copy_example(example_name)
      examples_dir = File.join(Roast::ROOT, "examples")
      source_path = File.join(examples_dir, example_name)
      target_path = File.join(Dir.pwd, example_name)

      unless File.directory?(source_path)
        puts "Example '#{example_name}' not found!"
        return
      end

      if File.exist?(target_path)
        puts "Directory '#{example_name}' already exists in current directory!"
        return
      end

      FileUtils.cp_r(source_path, target_path)
      puts "Successfully copied example '#{example_name}' to current directory."
    end

    def create_from_prompt
      puts("Create a new workflow from a description")
      puts

      # Execute the workflow generator
      generator_path = File.join(Roast::ROOT, "examples", "workflow_generator", "workflow.yml")

      begin
        # Execute the workflow generator (it will handle user input)
        Roast::Workflow::ConfigurationParser.new(generator_path, [], {}).begin!

        puts
        puts("Workflow generation complete!")
      rescue => e
        puts("Error generating workflow: #{e.message}")
      end
    end

    class << self
      def exit_on_failure?
        true
      end
    end
  end
end
