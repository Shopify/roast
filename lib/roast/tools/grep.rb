# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module Grep
      extend self

      MAX_RESULT_LINES = 100

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :grep,
              'Search for a string in the project using `grep -rni "#{@search_string}" .` in the project root',
              string: { type: "string", description: "The string to search for" },
            ) do |params|
              Roast::Tools::Grep.call(params[:string]).tap do |result|
                Roast::Helpers::Logger.debug(result) if ENV["DEBUG"]
              end
            end
          end
        end
      end

      def call(string)
        Roast::Helpers::Logger.info("🔍 Grepping for string: #{string}\n")

        # Check if ripgrep is available by trying to run it with --version
        unless Roast::Helpers::CmdRunner.system("rg --version > /dev/null 2>&1")
          raise "ripgrep is not available. Please install it using your package manager (e.g., brew install rg) and make sure it's on your PATH."
        end

        # Use Open3 to safely pass the string as an argument, avoiding shell injection
        cmd = ["rg", "-C", "4", "--trim", "--color=never", "--heading", "-F", "--", string, "."]
        stdout, stderr, status = Roast::Helpers::CmdRunner.capture3(*cmd)
        unless status.success?
          return "Error grepping for string: Command failed: #{stderr}"
        end

        # Limit output to MAX_RESULT_LINES
        lines = stdout.lines
        if lines.size > MAX_RESULT_LINES
          lines.first(MAX_RESULT_LINES).join + "\n... (truncated to #{MAX_RESULT_LINES} lines)"
        else
          stdout
        end
      rescue Roast::Error => e
        "Error grepping for string: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end
    end
  end
end
