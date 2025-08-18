# typed: true
# frozen_string_literal: true

# Standard library requires
require "digest"
require "English"
require "erb"
require "fileutils"
require "json"
require "logger"
require "net/http"
require "open3"
require "pathname"
require "securerandom"
require "shellwords"
require "tempfile"
require "timeout"
require "uri"
require "yaml"

# Third-party gem requires
require "active_support"
require "active_support/cache"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "cli/ui"
require "cli/kit"
require "diff/lcs"
require "json-schema"
require "raix"
require "raix/chat_completion"
require "raix/function_dispatch"
require "ruby-graphviz"
require "thor"

# Autoloading setup
require "zeitwerk"

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("dsl" => "DSL")
loader.setup

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
    option :file_storage, type: :boolean, aliases: "-f", desc: "Use filesystem storage for sessions instead of SQLite"
    option :experimental_ruby_dsl, type: :boolean, desc: "EXPERIMENTAL: execute workflows via Ruby DSL. may break at any time"

    def execute(*paths)
      raise Thor::Error, "Workflow configuration file is required" if paths.empty?

      workflow_path, *files = paths

      if options[:experimental_ruby_dsl]
        Roast::DSL::Executor.from_file(workflow_path)
      else
        expanded_workflow_path = if workflow_path.include?("workflow.yml")
          File.expand_path(workflow_path)
        else
          File.expand_path("roast/#{workflow_path}/workflow.yml")
        end

        raise Thor::Error, "Expected a Roast workflow configuration file, got directory: #{expanded_workflow_path}" if File.directory?(expanded_workflow_path)

        Roast::Workflow::WorkflowRunner.new(expanded_workflow_path, files, options.transform_keys(&:to_sym)).begin!
      end
    rescue => e
      if options[:verbose]
        raise e
      else
        $stderr.puts e.message
      end
    end

    desc "resume WORKFLOW_FILE", "Resume a paused workflow with an event"
    option :event, type: :string, aliases: "-e", required: true, desc: "Event name to trigger"
    option :session_id, type: :string, aliases: "-s", desc: "Specific session ID to resume (defaults to most recent)"
    option :event_data, type: :string, desc: "JSON data to pass with the event"
    def resume(workflow_path)
      expanded_workflow_path = if workflow_path.include?("workflow.yml")
        File.expand_path(workflow_path)
      else
        File.expand_path("roast/#{workflow_path}/workflow.yml")
      end

      unless File.exist?(expanded_workflow_path)
        raise Thor::Error, "Workflow file not found: #{expanded_workflow_path}"
      end

      # Store the event in the session
      repository = Workflow::StateRepositoryFactory.create

      unless repository.respond_to?(:add_event)
        raise Thor::Error, "Event resumption requires SQLite storage. Set ROAST_STATE_STORAGE=sqlite"
      end

      # Parse event data if provided
      event_data = options[:event_data] ? JSON.parse(options[:event_data]) : nil

      # Add the event to the session
      session_id = options[:session_id]
      repository.add_event(expanded_workflow_path, session_id, options[:event], event_data)

      # Resume workflow execution from the wait state
      resume_options = options.transform_keys(&:to_sym).merge(
        resume_from_event: options[:event],
        session_id: session_id,
      )

      Roast::Workflow::WorkflowRunner.new(expanded_workflow_path, [], resume_options).begin!
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

    desc "list", "List workflows visible to Roast and their source"
    def list
      roast_dir = File.join(Dir.pwd, "roast")

      unless File.directory?(roast_dir)
        raise Thor::Error, "No roast/ directory found in current path"
      end

      workflow_files = Dir.glob(File.join(roast_dir, "**/workflow.yml")).sort

      if workflow_files.empty?
        raise Thor::Error, "No workflow.yml files found in roast/ directory"
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

    desc "validate [WORKFLOW_CONFIGURATION_FILE]", "Validate a workflow configuration"
    option :strict, type: :boolean, aliases: "-s", desc: "Treat warnings as errors"
    def validate(workflow_path = nil)
      validation_command = Roast::Workflow::ValidationCommand.new(options)
      validation_command.execute(workflow_path)
    end

    desc "sessions", "List stored workflow sessions"
    option :status, type: :string, aliases: "-s", desc: "Filter by status (running, waiting, completed, failed)"
    option :workflow, type: :string, aliases: "-w", desc: "Filter by workflow name"
    option :older_than, type: :string, desc: "Show sessions older than specified time (e.g., '7d', '1h')"
    option :cleanup, type: :boolean, desc: "Clean up old sessions"
    def sessions
      repository = Workflow::StateRepositoryFactory.create

      unless repository.respond_to?(:list_sessions)
        raise Thor::Error, "Session listing is only available with SQLite storage. Set ROAST_STATE_STORAGE=sqlite"
      end

      if options[:cleanup] && options[:older_than]
        count = repository.cleanup_old_sessions(options[:older_than])
        puts "Cleaned up #{count} old sessions"
        return
      end

      sessions = repository.list_sessions(
        status: options[:status],
        workflow_name: options[:workflow],
        older_than: options[:older_than],
      )

      if sessions.empty?
        puts "No sessions found"
        return
      end

      puts "Found #{sessions.length} session(s):"
      puts

      sessions.each do |session|
        id, workflow_name, _, status, current_step, created_at, updated_at = session

        puts "Session: #{id}"
        puts "  Workflow: #{workflow_name}"
        puts "  Status: #{status}"
        puts "  Current step: #{current_step || "N/A"}"
        puts "  Created: #{created_at}"
        puts "  Updated: #{updated_at}"
        puts
      end
    end

    desc "session SESSION_ID", "Show details for a specific session"
    def session(session_id)
      repository = Workflow::StateRepositoryFactory.create

      unless repository.respond_to?(:get_session_details)
        raise Thor::Error, "Session details are only available with SQLite storage. Set ROAST_STATE_STORAGE=sqlite"
      end

      details = repository.get_session_details(session_id)

      unless details
        raise Thor::Error, "Session not found: #{session_id}"
      end

      session = details[:session]
      states = details[:states]
      events = details[:events]

      puts "Session: #{session[0]}"
      puts "Workflow: #{session[1]}"
      puts "Path: #{session[2]}"
      puts "Status: #{session[3]}"
      puts "Created: #{session[6]}"
      puts "Updated: #{session[7]}"

      if session[5]
        puts
        puts "Final output:"
        puts session[5]
      end

      if states && !states.empty?
        puts
        puts "Steps executed:"
        states.each do |step_index, step_name, created_at|
          puts "  #{step_index}: #{step_name} (#{created_at})"
        end
      end

      if events && !events.empty?
        puts
        puts "Events:"
        events.each do |event_name, event_data, received_at|
          puts "  #{event_name} at #{received_at}"
          puts "    Data: #{event_data}" if event_data
        end
      end
    end

    desc "diagram WORKFLOW_FILE", "Generate a visual diagram of a workflow"
    option :output, type: :string, aliases: "-o", desc: "Output file path (defaults to workflow_name_diagram.png)"
    def diagram(workflow_file)
      unless File.exist?(workflow_file)
        raise Thor::Error, "Workflow file not found: #{workflow_file}"
      end

      workflow = Workflow::Configuration.new(workflow_file)
      generator = WorkflowDiagramGenerator.new(workflow, workflow_file)
      output_path = generator.generate(options[:output])

      puts ::CLI::UI.fmt("{{success:✓}} Diagram generated: #{output_path}")
    rescue StandardError => e
      raise Thor::Error, "Error generating diagram: #{e.message}"
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
        Roast::Workflow::WorkflowRunner.new(generator_path, [], {}).begin!

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
