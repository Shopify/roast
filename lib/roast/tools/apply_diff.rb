# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module ApplyDiff
      extend self

      class << self
        def included(base)
          base.class_eval do
            function(
              :apply_diff,
              "Show a diff to the user and apply changes based on their yes/no response",
              file_path: { type: "string", description: "Path to the file to modify" },
              old_content: { type: "string", description: "The current content to be replaced" },
              new_content: { type: "string", description: "The new content to replace with" },
              description: { type: "string", description: "Optional description of the change", required: false },
            ) do |params|
              Roast::Tools::ApplyDiff.call(
                params[:file_path],
                params[:old_content],
                params[:new_content],
                params[:description],
              )
            end
          end
        end
      end

      def call(file_path, old_content, new_content, description = nil)
        unless File.exist?(file_path)
          error_msg = "File not found: #{file_path}"
          Roast::Helpers::Logger.error(error_msg + "\n")
          return error_msg
        end

        current_content = File.read(file_path)
        unless current_content.include?(old_content)
          error_msg = "Old content not found in file: #{file_path}"
          Roast::Helpers::Logger.error(error_msg + "\n")
          return error_msg
        end

        # Show the diff
        show_diff(file_path, old_content, new_content, description)

        # Ask for confirmation
        prompt_text = "Apply this change? (y/n)"
        response = ::CLI::UI::Prompt.ask(prompt_text)

        if response.to_s.downcase.start_with?("y")
          # Apply the change
          updated_content = current_content.gsub(old_content, new_content)
          File.write(file_path, updated_content)

          success_msg = "✅ Changes applied to #{file_path}"
          Roast::Helpers::Logger.info(success_msg + "\n")
          success_msg
        else
          cancel_msg = "❌ Changes cancelled for #{file_path}"
          Roast::Helpers::Logger.info(cancel_msg + "\n")
          cancel_msg
        end
      rescue Roast::Error, Errno::EACCES, Errno::ENOENT => e
        error_message = "Error applying diff: #{e.message}"
        Roast::Helpers::Logger.error(error_message + "\n")
        Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        error_message
      end

      private

      def show_diff(file_path, old_content, new_content, description)
        require "tmpdir"

        Roast::Helpers::Logger.info("📝 Proposed change for #{file_path}:\n")

        if description
          Roast::Helpers::Logger.info("Description: #{description}\n\n")
        end

        # Create temporary files for git diff
        Dir.mktmpdir do |tmpdir|
          # Write current content with old_content replaced by new_content
          current_content = File.read(file_path)
          updated_content = current_content.gsub(old_content, new_content)

          # Create temp file with the proposed changes
          temp_file = File.join(tmpdir, File.basename(file_path))
          File.write(temp_file, updated_content)

          # Run git diff
          diff_output, _status = Roast::Helpers::CmdRunner.capture2e("git", "diff", "--no-index", "--no-prefix", file_path, temp_file)

          if diff_output.empty?
            Roast::Helpers::Logger.info("No differences found (files are identical)\n")
          else
            # Clean up the diff output - remove temp file paths and use relative paths with colors
            cleaned_diff = diff_output.lines.map do |line|
              case line
              when /^diff --git /
                ::CLI::UI.fmt("{{bold:diff --git a/#{file_path} b/#{file_path}}}")
              when /^--- /
                ::CLI::UI.fmt("{{red:--- a/#{file_path}}}")
              when /^\+\+\+ /
                ::CLI::UI.fmt("{{green:+++ b/#{file_path}}}")
              when /^@@/
                ::CLI::UI.fmt("{{cyan:#{line.chomp}}}")
              when /^-/
                ::CLI::UI.fmt("{{red:#{line.chomp}}}")
              when /^\+/
                ::CLI::UI.fmt("{{green:#{line.chomp}}}")
              else
                line.chomp
              end
            end.join("\n")

            Roast::Helpers::Logger.info("#{cleaned_diff}\n")
          end
        end

        Roast::Helpers::Logger.info("\n")
      end
    end
  end
end
