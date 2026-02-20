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
require "optparse"
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
require "active_support/core_ext/hash"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string"
require "active_support/core_ext/string/inflections"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "async"
require "async/semaphore"
require "ruby_llm"

# Require project components that will not get automatically loaded
require "roast/nil_assertions"

# Autoloading setup
require "zeitwerk"

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/roast-ai.rb")
loader.setup

module Roast
  class CLI
    COMMANDS = ["execute", "version", "help"].freeze

    class << self
      def start(argv)
        roast_args, extra_args = split_at_separator(argv)

        show_help = false #: bool
        parser = OptionParser.new do |opts|
          opts.on("-h", "--help") { show_help = true }
        end
        parser.order!(roast_args)

        command = roast_args.first
        if show_help || command == "help"
          help
        elsif command == "version"
          puts "Roast version #{Roast::VERSION}"
        elsif command == "execute"
          roast_args.shift
          run_execute(roast_args, extra_args)
        elsif command && resolve_workflow_path(command)
          run_execute(roast_args, extra_args)
        elsif command
          $stderr.puts "Could not find command or workflow file \"#{command}\"\n\n"
          help
          exit(1)
        else
          help
        end
      end

      private

      def run_execute(args, extra_args)
        if args.empty?
          $stderr.puts "Error: Workflow file is required\n\n"
          help
          exit(1)
        end

        workflow_path, *targets = args
        real_workflow_path = resolve_workflow_path(workflow_path)
        unless real_workflow_path
          $stderr.puts "Error: Workflow file not found: #{workflow_path}\n\n"
          help
          exit(1)
        end

        workflow_args, workflow_kwargs = parse_custom_workflow_args(extra_args)
        workflow_params = Roast::WorkflowParams.new(targets, workflow_args, workflow_kwargs)
        roast_working_directory = Pathname.new(File.expand_path(ENV["ROAST_WORKING_DIRECTORY"] || Dir.pwd))
        Dir.chdir(roast_working_directory) do
          Roast::Workflow.from_file(real_workflow_path, workflow_params)
        end
      end

      # Resolve a workflow path string to a real filesystem path.
      # Returns the resolved Pathname, or nil if the file cannot be found.
      #: (String) -> Pathname?
      def resolve_workflow_path(workflow_path)
        roast_working_directory = Pathname.new(File.expand_path(ENV["ROAST_WORKING_DIRECTORY"] || Dir.pwd))
        path = Pathname.new(workflow_path)
        resolved = if path.absolute? || path.exist?
          path
        else
          roast_working_directory / path
        end
        resolved.realpath
      rescue Errno::ENOENT
        nil
      end

      #: (Array[String]) -> [Array[Symbol], Hash[Symbol, String]]
      def parse_custom_workflow_args(extra_args)
        args = []
        kwargs = {}
        extra_args.each do |arg|
          arg = arg.sub(/^--?(?=[^-])/, "")
          if arg.include?("=")
            key, value = arg.split("=", 2)
            kwargs[key.to_sym] = value if key
          else
            args << arg.to_sym
          end
        end
        [args, kwargs]
      end

      def help
        $stderr.puts <<~HELP
          Usage: roast <workflow_file> [options] [targets...] [-- workflow_args]
                 roast execute <workflow_file> [options] [targets...] [-- workflow_args]

          Commands:
            execute  Run a workflow (optional; any unrecognized command is treated as a workflow file to execute)
            version  Display the current version of Roast
            help     Show this help message

          Options:
            -h, --help     Show this help message
        HELP
      end

      def split_at_separator(argv)
        index = argv.index("--")
        if index
          [argv[0...index], argv[(index + 1)..]]
        else
          [argv.dup, []]
        end
      end
    end
  end
end
