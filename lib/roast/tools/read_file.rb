# frozen_string_literal: true

require "roast/helpers/logger"
require "roast/helpers/content_truncator"

module Roast
  module Tools
    module ReadFile
      extend self

      class << self
        def included(base)
          base.class_eval do
            function(
              :read_file,
              "Read the contents of a file. (If the path is a directory, list the contents.) " \
                "NOTE: Do not use for .rbi files, they are not useful.",
              path: { type: "string", description: "The path to the file to read" },
              max_tokens: { type: "integer", description: "Optional maximum tokens to return (will truncate if exceeded)" },
            ) do |params|
              Roast::Tools::ReadFile.call(params[:path], max_tokens: params[:max_tokens]).tap do |result|
                if ENV["DEBUG"]
                  result_lines = result.lines
                  if result_lines.size > 20
                    Roast::Helpers::Logger.debug(result_lines.first(20).join + "\n...")
                  else
                    Roast::Helpers::Logger.debug(result)
                  end
                end
              end
            end
          end
        end
      end

      def call(path, max_tokens: nil)
        path = File.expand_path(path)
        Roast::Helpers::Logger.info("📖 Reading file: #{path}\n")
        
        content = if File.directory?(path)
          %x(ls -la #{path})
        else
          File.read(path)
        end
        
        # Apply token truncation if max_tokens is specified
        if max_tokens && content.length > 0
          Roast::Helpers::ContentTruncator.truncate_content(content, max_tokens)
        else
          content
        end
      rescue StandardError => e
        "Error reading file: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

    end
  end
end
