# typed: true
# frozen_string_literal: true

# Standard library requires
require "benchmark"
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
require "active_support/core_ext/array"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "async"
require "async/semaphore"
require "cli/kit"
require "cli/ui"
require "diff/lcs"
require "json-schema"
require "raix"
require "raix/chat_completion"
require "raix/function_dispatch"
require "ruby_llm"
require "thor"
require "timeout"

unless defined?(T)
  # NOTE: stubs for sorbet-runtime were being imported from cli-kit. They were removed in cli-kit v5.2
  # Ideally we will not need them at all in the future, but for now I have brought them into the project
  # because a large quantity of legacy code is using sorbet runtime assertions.
  require("roast/sorbet_runtime_stub")
end

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
    option :target, type: :string, aliases: "-t", desc: "Override target files. Can be file path, glob pattern, or $(shell command)"

    def execute(*paths)
      raise Thor::Error, "Workflow configuration file is required" if paths.empty?

      workflow_path, *files = paths
      targets, workflow_args, workflow_kwargs = parse_custom_workflow_args(files, ARGV)
      targets.unshift(options[:target]) if options[:target]
      workflow_params = Roast::DSL::WorkflowParams.new(targets, workflow_args, workflow_kwargs)
      Roast::DSL::Workflow.from_file(workflow_path, workflow_params)
    rescue => e
      $stderr.puts e.message
      raise e if ENV["ROAST_DEBUG"]
    end

    desc "version", "Display the current version of Roast"
    def version
      puts "Roast version #{Roast::VERSION}"
    end

    desc "init", "Initialize a new Roast workflow from an example"
    option :example, type: :string, aliases: "-e", desc: "Name of the example to use directly (skips picker)"
    def init
      raise NotImplementedError, "Example workflows for the new DSL are coming soon. For now, see the examples in the dsl/ directory of the roast repository."
    end

    desc "list", "List workflows visible to Roast and their source"
    def list
      roast_dir = File.join(Dir.pwd, "roast")

      unless File.directory?(roast_dir)
        raise Thor::Error, "No roast/ directory found in current path"
      end

      workflow_files = Dir.glob(File.join(roast_dir, "**/*.rb")).sort

      if workflow_files.empty?
        raise Thor::Error, "No workflow files found in roast/ directory"
      end

      puts "Available workflows:"
      puts

      workflow_files.each do |file|
        workflow_name = file.sub("#{roast_dir}/", "")
        puts "  #{workflow_name} (from project)"
      end

      puts
      puts "Run a workflow with: roast execute <workflow_file>"
    end

    desc "validate [WORKFLOW_CONFIGURATION_FILE]", "Validate a workflow configuration"
    option :strict, type: :boolean, aliases: "-s", desc: "Treat warnings as errors"
    def validate(workflow_path = nil)
      raise NotImplementedError, "Validation for DSL workflows is not yet implemented"
    end

    private

    #: (Array[String], Array[String]) -> [Array[String], Array[Symbol], Hash[Symbol, String]]
    def parse_custom_workflow_args(parsed_args, raw_args)
      separator_index = raw_args.index("--")
      extra_args = (separator_index ? raw_args[(separator_index + 1)..] : []) || []
      targets = parsed_args.shift(parsed_args.length - extra_args.length)
      args = []
      kwargs = {}
      parsed_args.each do |arg|
        if arg.include?("=")
          key, value = arg.split("=", 2)
          kwargs[key.to_sym] = value if key
        else
          args << arg.to_sym
        end
      end
      [targets, args, kwargs]
    end

    class << self
      def exit_on_failure?
        true
      end
    end
  end
end
