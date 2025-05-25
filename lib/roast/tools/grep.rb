# frozen_string_literal: true

require "roast/helpers/logger"

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
        # Escape regex special characters in strings with curly braces
        # Example: "import {render}" becomes "import \{render\}"
        escaped_string = string.gsub(/(\{|\})/, '\\\\\\1')
        %x(rg -C 4 --trim --color=never --heading -F -- "#{escaped_string}" . | head -n #{MAX_RESULT_LINES})
      rescue StandardError => e
        "Error grepping for string: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end
    end
  end
end
