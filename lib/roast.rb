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
require "pp"
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
require "ruby-graphviz"
require "ruby_llm"
require "thor"
require "timeout"

unless defined?(T)
  # NOTE: stubs for sorbet-runtime were being imported from cli-kit. They were removed in cli-kit v5.2
  # Ideally we will not need them at all in the future, but for now I have brought them into the project
  # because a large quantity of legacy code is using sorbet runtime assertions.
  require("roast/sorbet_runtime_stub")
end

# Require project components that will not get automatically loaded
require "roast/dsl/nil_assertions"

# Autoloading setup
require "zeitwerk"

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("dsl" => "DSL")
loader.ignore("#{__dir__}/roast-ai.rb")
loader.setup

module Roast
  ROOT = File.expand_path("../..", __FILE__)

  class CLI < Thor
    desc "execute [WORKFLOW_CONFIGURATION_FILE] [FILES...]", "Run a workflow"
    option :verbose, type: :boolean, aliases: "-v", desc: "Show output from all steps as they are executed"
    option :executor, type: :string, default: "dsl", desc: "Set workflow executor (DEPRECATED: 'dsl' is the only valid option)"

    def execute(*paths)
      raise Thor::Error, "Workflow file is required" if paths.empty?
      raise StandardError, "'dsl' is the only valid executor" if options[:executor] != "dsl"

      workflow_path, *files = paths

      targets, workflow_args, workflow_kwargs = parse_custom_workflow_args(files, ARGV)
      targets.unshift(options[:target]) if options[:target]
      workflow_params = Roast::DSL::WorkflowParams.new(targets, workflow_args, workflow_kwargs)

      # If the workflow is running with a working directory specified to be different from the current directory
      # from which Roast was run, and the workflow file if specified with a relative path, check for it relative
      # to the current directory first, and then relative to the working directory specified for the workflow.
      roast_working_directory = Pathname.new(File.expand_path(ENV["ROAST_WORKING_DIRECTORY"] || Dir.pwd))
      workflow_path = Pathname.new(workflow_path)
      real_workflow_path = if workflow_path.absolute? || workflow_path.exist?
        workflow_path
      else
        roast_working_directory / workflow_path
      end.realpath

      Dir.chdir(roast_working_directory) do
        Roast::DSL::Workflow.from_file(real_workflow_path, workflow_params)
      end
    rescue => e
      if options[:verbose]
        raise e
      else
        $stderr.puts e.message
      end
    end

    desc "version", "Display the current version of Roast"

    def version
      puts "Roast version #{Roast::VERSION}"
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
