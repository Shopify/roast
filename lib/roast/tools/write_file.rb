# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module WriteFile
      extend self

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :write_file,
              "Write content to a file. Creates the file if it does not exist, or overwrites it if it does.",
              path: {
                type: "string",
                description: "The path to the file to write, relative to the current working directory: #{Dir.pwd}",
              },
              content: { type: "string", description: "The content to write to the file" },
            ) do |params|
              restrict_path = params[:params]&.dig("restrict")

              Roast::Tools::WriteFile.call(params[:path], params[:content], restrict_path).tap do |_result|
                Roast::Helpers::Logger.info(params[:content])
              end
            end
          end
        end
      end

      def call(path, content, restrict_path = nil)
        if restrict_path.nil? || restrict_path.empty? || path.start_with?(restrict_path)
          Roast::Helpers::Logger.info("📝 Writing to file: #{path}\n")

          # Ensure the directory exists
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          # Write the content to the file
          # Check if path is absolute or relative
          absolute_path = path.start_with?("/") ? path : File.join(Dir.pwd, path)

          File.write(absolute_path, content)

          "Successfully wrote #{content.lines.count} lines to #{path}"
        else
          restriction_message = "😳 Path must start with '#{restrict_path}' to use the write_file tool\n"
          Roast::Helpers::Logger.error(restriction_message)
          "Error: Path must start with '#{restrict_path}' to use the write_file tool, try again."
        end
      rescue Roast::Error, Errno::EACCES, Errno::ENOENT => e
        "Error writing file: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end
    end
  end
end
