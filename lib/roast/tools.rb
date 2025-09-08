# typed: true
# frozen_string_literal: true

require "roast/helpers/cmd_runner"

module Roast
  # @requires_ancestor: Kernel
  module Tools
    extend self

    # Initialize cache and ensure .gitignore exists
    cache_dir = File.join(Dir.pwd, ".roast", "cache")
    FileUtils.mkdir_p(cache_dir) unless File.directory?(cache_dir)

    # Add .gitignore to cache directory
    gitignore_path = File.join(cache_dir, ".gitignore")
    File.write(gitignore_path, "*") unless File.exist?(gitignore_path)

    CACHE = ActiveSupport::Cache::FileStore.new(cache_dir)

    def file_to_prompt(file)
      <<~PROMPT
        # #{file}

        #{File.read(file)}
      PROMPT
    rescue Roast::Error => e
      Roast::Helpers::Logger.error("In current directory: #{Dir.pwd}\n")
      Roast::Helpers::Logger.error("Error reading file #{file}\n")

      raise e # unable to continue without required file
    end

    def setup_interrupt_handler(object_to_inspect)
      Signal.trap("INT") do
        puts "\n\nCaught CTRL-C! Printing before exiting:\n"
        puts JSON.pretty_generate(object_to_inspect)

        begin
          Roast::Helpers::CmdRunner.cleanup_all_children
        rescue => e
          puts "Error interrupting tracked child processes: #{e.message}"
        end

        exit(130)
      end
    end

    def setup_exit_handler(context)
      # Hook that runs on any exit (including crashes and unhandled exceptions)
      at_exit do
        if $ERROR_INFO && !$ERROR_INFO.is_a?(SystemExit) # If exiting due to unhandled exception
          # Print a more user-friendly message based on the error type
          case $ERROR_INFO
          when Roast::Workflow::CommandExecutor::CommandExecutionError
            puts "\n\n🛑 Workflow stopped due to command failure."
            puts "   To continue execution despite command failures, you can:"
            puts "   - Fix the failing command"
            puts "   - Run with --verbose to see command output"
            puts "   - Modify your workflow to handle errors gracefully"
          when Roast::Workflow::WorkflowExecutor::StepExecutionError
            puts "\n\n🛑 Workflow stopped due to step failure."
            puts "   Check the error message above for details."
          else
            puts "\n\n🛑 Workflow stopped due to an unexpected error:"
            puts "   #{$ERROR_INFO.class}: #{$ERROR_INFO.message}"
          end
          puts "\nFor debugging, you can run with --verbose for more details."
          # Temporary disable the debugger to fix directory issues
          # context.instance_eval { binding.irb }
        end
      end
    end
  end
end
