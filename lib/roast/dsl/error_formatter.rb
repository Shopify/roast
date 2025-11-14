# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ErrorFormatter
      #: (?untyped) -> void
      def initialize(workflow = nil)
        @workflow = workflow
      end

      #: (Exception, ?step_name: String?) -> void
      def print_error(error, step_name: nil)
        formatted_message = format_error(error, step_name: step_name)
        $stderr.puts formatted_message
      end

      private

      #: (Exception, ?step_name: String?) -> String
      def format_error(error, step_name: nil)
        case error
        when SyntaxError
          format_syntax_error(error)
        when NameError, NoMethodError
          format_undefined_error(error)
        when Roast::DSL::Cog::Input::InvalidInputError
          format_cog_input_error(error)
        when Roast::DSL::Cog::Config::InvalidConfigError
          format_cog_config_error(error)
        else
          format_generic_error(error)
        end
      end

      #: (SyntaxError) -> String
      def format_syntax_error(error)
        <<~ERROR
          #{::CLI::UI.fmt("{{red:❌ Syntax Error in DSL Workflow}}")}

          #{::CLI::UI.fmt("{{yellow:Problem:}}")} Invalid Ruby syntax in workflow definition

          #{::CLI::UI.fmt("{{yellow:Details:}}")} #{error.message}

          #{::CLI::UI.fmt("{{yellow:Solution:}}")} Check your workflow file for proper Ruby syntax
        ERROR
      end

      #: (Exception) -> String
      def format_undefined_error(error)
        <<~ERROR
          #{::CLI::UI.fmt("{{red:❌ Undefined Reference in DSL Workflow}}")}

          #{::CLI::UI.fmt("{{yellow:Problem:}}")} #{error.class.name}

          #{::CLI::UI.fmt("{{yellow:Details:}}")} #{error.message}

          #{::CLI::UI.fmt("{{yellow:Solution:}}")} Check that all cogs and methods are properly defined
        ERROR
      end

      #: (Exception) -> String
      def format_cog_input_error(error)
        <<~ERROR
          #{::CLI::UI.fmt("{{red:❌ Cog Input Validation Failed}}")}

          #{::CLI::UI.fmt("{{yellow:Problem:}}")} Invalid input provided to cog

          #{::CLI::UI.fmt("{{yellow:Details:}}")} #{error.message}

          #{::CLI::UI.fmt("{{yellow:Solution:}}")} Check the input provided to your cog matches its requirements
        ERROR
      end

      #: (Exception) -> String
      def format_cog_config_error(error)
        <<~ERROR
          #{::CLI::UI.fmt("{{red:❌ Cog Configuration Error}}")}

          #{::CLI::UI.fmt("{{yellow:Problem:}}")} Invalid cog configuration

          #{::CLI::UI.fmt("{{yellow:Details:}}")} #{error.message}

          #{::CLI::UI.fmt("{{yellow:Solution:}}")} Check your cog configuration in the workflow
        ERROR
      end

      #: (Exception) -> String
      def format_generic_error(error)
        <<~ERROR
          #{::CLI::UI.fmt("{{red:❌ DSL Workflow Error}}")}

          #{::CLI::UI.fmt("{{yellow:Problem:}}")} #{error.class.name}

          #{::CLI::UI.fmt("{{yellow:Details:}}")} #{error.message}

          #{format_filtered_backtrace(error)}
        ERROR
      end

      #: (Exception) -> String
      def format_filtered_backtrace(error)
        return "" unless error.backtrace

        # Show only the first few lines, filtering out internal gems
        relevant_lines = error.backtrace&.take(5)&.reject do |line|
          line.include?("/gems/") && !line.include?("roast")
        end

        return "" if relevant_lines.nil? || relevant_lines.empty?

        formatted_lines = relevant_lines.map { |line| "  #{line}" }.join("\n")
        "\n#{::CLI::UI.fmt("{{yellow:Stack trace:}}")}\n#{formatted_lines}"
      end
    end
  end
end
