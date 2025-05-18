# frozen_string_literal: true

require "roast/helpers/logger"

module Roast
  module Tools
    module SearchFile
      extend self

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :search_for_file,
              "Search for a file in the project using a glob pattern to match the file name. Only the first 100 results are returned.",
              glob_pattern: { type: "string", description: "A glob pattern to search for. Example: 'test/**/*_test.rb'" },
              path: { type: "string", description: "path to search from" },
            ) do |params|
              Roast::Tools::SearchFile.call(params[:glob_pattern], params[:path]).tap do |result|
                Roast::Helpers::Logger.debug(result) if ENV["DEBUG"]
              end
            end
          end
        end
      end

      def call(glob_pattern, path = ".")
        path = path.to_s
        Roast::Helpers::Logger.info("🔍 Searching for: '#{glob_pattern}' in '#{File.expand_path(path)}'\n")
        search_for(glob_pattern, path).then do |results|
          return "No results found for #{glob_pattern} in #{path}" if results.empty?
          return read_contents(results.first) if results.size == 1

          results.join("\n") # purposely give the AI list of actual paths so that it can read without searching first
        end
      rescue StandardError => e
        "Error searching for '#{glob_pattern}' in '#{path}': #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      def read_contents(path)
        contents = File.read(path)
        token_count = contents.size / 4
        if token_count > 25_000
          path
        else
          contents
        end
      end

      def search_for(pattern, path)
        Dir.glob(pattern, base: path).first(100)
      end
    end
  end
end
