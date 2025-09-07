# typed: false
# frozen_string_literal: true

module Roast
  module Tools
    module UpdateFiles
      extend self

      class << self
        # Add this method to be included in other classes
        def included(base)
          base.class_eval do
            function(
              :update_files,
              "Apply a unified diff/patch to files in the workspace. Changes are applied atomically if possible.",
              diff: {
                type: "string",
                description: "The unified diff/patch content to apply",
              },
              base_path: {
                type: "string",
                description: "Base path for relative file paths in the diff (default: current working directory)",
                required: false,
              },
              restrict_path: {
                type: "string",
                description: "Optional path restriction to limit where files can be modified",
                required: false,
              },
              create_files: {
                type: "boolean",
                description: "Whether to create new files if they don't exist (default: true)",
                required: false,
              },
            ) do |params|
              base_path = params[:base_path] || Dir.pwd
              create_files = params.fetch(:create_files, true)
              restrict_path = params[:restrict_path]

              Roast::Tools::UpdateFiles.call(
                params[:diff],
                base_path,
                restrict_path,
                create_files,
              )
            end
          end
        end
      end

      # Apply a unified diff to files
      # @param diff [String] unified diff content
      # @param base_path [String] base path for relative paths in the diff
      # @param restrict_path [String, nil] optional path restriction
      # @param create_files [Boolean] whether to create new files if they don't exist
      # @return [String] result message
      def call(diff, base_path = Dir.pwd, restrict_path = nil, create_files = true)
        Roast::Helpers::Logger.info("🔄 Applying patch to files\n")

        # Parse the unified diff to identify files and changes
        file_changes = parse_unified_diff(diff)

        if file_changes.empty?
          return "Error: No valid file changes found in the provided diff"
        end

        # Validate changes
        validation_result = validate_changes(file_changes, base_path, restrict_path, create_files)
        return validation_result if validation_result.is_a?(String) && validation_result.start_with?("Error:")

        # Apply changes atomically
        apply_changes(file_changes, base_path, create_files)
      rescue Roast::Error => e
        "Error applying patch: #{e.message}".tap do |error_message|
          Roast::Helpers::Logger.error(error_message + "\n")
          Roast::Helpers::Logger.debug(e.backtrace.join("\n") + "\n") if ENV["DEBUG"]
        end
      end

      private

      # Parse a unified diff to extract file changes
      # @param diff [String] unified diff content
      # @return [Array<Hash>] array of file change objects
      def parse_unified_diff(diff)
        lines = diff.split("\n")
        file_changes = []
        current_files = { src: nil, dst: nil }
        current_hunks = []

        i = 0
        while i < lines.length
          line = lines[i]

          # New file header (--- line followed by +++ line)
          if line.start_with?("--- ") && i + 1 < lines.length && lines[i + 1].start_with?("+++ ")
            # Save previous file if exists
            if current_files[:src] && current_files[:dst] && !current_hunks.empty?
              file_changes << {
                src_path: current_files[:src],
                dst_path: current_files[:dst],
                hunks: current_hunks.dup,
              }
            end

            # Extract new file paths
            current_files = {
              src: extract_file_path(line),
              dst: extract_file_path(lines[i + 1]),
            }
            current_hunks = []
            i += 2
            next
          end

          # Hunk header
          if line.match(/^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@/)
            current_hunk = { header: line, changes: [] }

            # Parse the header
            header_match = line.match(/@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/)
            if header_match
              current_hunk[:src_start] = header_match[1].to_i
              current_hunk[:src_count] = header_match[2] ? header_match[2].to_i : 1 # rubocop:disable Metrics/BlockNesting
              current_hunk[:dst_start] = header_match[3].to_i
              current_hunk[:dst_count] = header_match[4] ? header_match[4].to_i : 1 # rubocop:disable Metrics/BlockNesting
            end

            current_hunks << current_hunk
            i += 1
            next
          end

          # Capture content lines for the current hunk
          if !current_hunks.empty? && line.start_with?("+", "-", " ")
            current_hunks.last[:changes] << line
          end

          i += 1
        end

        # Add the last file
        if current_files[:src] && current_files[:dst] && !current_hunks.empty?
          file_changes << {
            src_path: current_files[:src],
            dst_path: current_files[:dst],
            hunks: current_hunks.dup,
          }
        end

        file_changes
      end

      # Extract file path from a diff header line
      # @param line [String] diff header line (--- or +++ line)
      # @return [String] file path
      def extract_file_path(line)
        # Handle special cases
        return "/dev/null" if line.include?("/dev/null")

        # Remove prefixes
        path = line.sub(%r{^(\+\+\+|\-\-\-) (a|b)/}, "")
        # Handle files without 'a/' or 'b/' prefix
        path = line.sub(/^(\+\+\+|\-\-\-) /, "") if path == line
        # Remove timestamps if present
        path = path.sub(/\t.*$/, "")
        path
      end

      # Validate changes before applying them
      # @param file_changes [Array<Hash>] array of file change objects
      # @param base_path [String] base path for relative paths
      # @param restrict_path [String, nil] optional path restriction
      # @param create_files [Boolean] whether to create new files if they don't exist
      # @return [Boolean, String] true if valid, error message if invalid
      def validate_changes(file_changes, base_path, restrict_path, create_files)
        # Validate each file in the changes
        file_changes.each do |file_change|
          # For destination files (they will be written to)
          if file_change[:dst_path] && file_change[:dst_path] != "/dev/null"
            absolute_path = File.expand_path(file_change[:dst_path], base_path)

            # Check path restriction
            if restrict_path && !absolute_path.start_with?(restrict_path)
              return "Error: Path #{file_change[:dst_path]} must start with '#{restrict_path}' to use the update_files tool"
            end

            # Check if file exists
            if !File.exist?(absolute_path) && !create_files
              return "Error: File #{file_change[:dst_path]} does not exist and create_files is false"
            end

            # Check if file is readable and writable if it exists
            if File.exist?(absolute_path)
              unless File.readable?(absolute_path)
                return "Error: File #{file_change[:dst_path]} is not readable"
              end

              unless File.writable?(absolute_path)
                return "Error: File #{file_change[:dst_path]} is not writable"
              end
            end
          end

          # For source files (they will be read from)
          next unless file_change[:src_path] && file_change[:src_path] != "/dev/null" && file_change[:src_path] != file_change[:dst_path]

          absolute_path = File.expand_path(file_change[:src_path], base_path)

          # Source file must exist unless it's a new file
          if !File.exist?(absolute_path) && file_change[:src_path] != "/dev/null"
            # Special case for new files (src: /dev/null)
            if file_change[:src_path] != "/dev/null"
              return "Error: Source file #{file_change[:src_path]} does not exist"
            end
          end

          # Check if file is readable if it exists
          next unless File.exist?(absolute_path)
          unless File.readable?(absolute_path)
            return "Error: Source file #{file_change[:src_path]} is not readable"
          end
        end

        true
      end

      # Apply changes to files
      # @param file_changes [Array<Hash>] array of file change objects
      # @param base_path [String] base path for relative paths
      # @param create_files [Boolean] whether to create new files if they don't exist
      # @return [String] result message
      def apply_changes(file_changes, base_path, create_files)
        # Create a temporary backup of all files to be modified
        backup_files = {}
        modified_files = []

        # Step 1: Create backups
        file_changes.each do |file_change|
          next unless file_change[:dst_path] && file_change[:dst_path] != "/dev/null"

          absolute_path = File.expand_path(file_change[:dst_path], base_path)

          if File.exist?(absolute_path)
            backup_files[absolute_path] = File.read(absolute_path)
          end
        end

        # Step 2: Try to apply all changes
        begin
          file_changes.each do |file_change|
            next unless file_change[:dst_path]

            # Special case for file deletion
            if file_change[:dst_path] == "/dev/null" && file_change[:src_path] != "/dev/null"
              absolute_src_path = File.expand_path(file_change[:src_path], base_path)
              if File.exist?(absolute_src_path)
                File.delete(absolute_src_path)
                modified_files << file_change[:src_path]
              end
              next
            end

            # Skip if both src and dst are /dev/null (shouldn't happen but just in case)
            next if file_change[:dst_path] == "/dev/null" && file_change[:src_path] == "/dev/null"

            absolute_dst_path = File.expand_path(file_change[:dst_path], base_path)

            # Special case for new files
            if file_change[:src_path] == "/dev/null"
              # For new files, ensure directory exists
              dir = File.dirname(absolute_dst_path)
              FileUtils.mkdir_p(dir) unless File.directory?(dir)

              # Create the file with the added content
              content = []
              file_change[:hunks].each do |hunk|
                hunk[:changes].each do |line|
                  content << line[1..-1] if line.start_with?("+")
                end
              end

              # Write the content
              File.write(absolute_dst_path, content.join("\n") + (content.empty? ? "" : "\n"))
              modified_files << file_change[:dst_path]
              next
            end

            # Normal case: Modify existing file
            content = ""
            if File.exist?(absolute_dst_path)
              content = File.read(absolute_dst_path)
            else
              # For new files that aren't from /dev/null, ensure directory exists
              dir = File.dirname(absolute_dst_path)
              FileUtils.mkdir_p(dir) unless File.directory?(dir)
            end
            content_lines = content.split("\n")

            # Apply each hunk to the file
            file_change[:hunks].each do |hunk|
              # Apply the changes to the content
              new_content_lines = apply_hunk(content_lines, hunk)

              # Check if the hunk was applied successfully
              if new_content_lines
                content_lines = new_content_lines
              else
                raise "Hunk could not be applied cleanly: #{hunk[:header]}"
              end
            end

            # Write the updated content
            File.write(absolute_dst_path, content_lines.join("\n") + (content_lines.empty? ? "" : "\n"))
            modified_files << file_change[:dst_path]
          end

          "Successfully applied patch to #{modified_files.size} file(s): #{modified_files.join(", ")}"
        rescue Roast::Error => e
          # Restore backups if any change fails
          backup_files.each do |path, content|
            File.write(path, content) if File.exist?(path)
          end

          "Error applying patch: #{e.message}"
        end
      end

      # Apply a single hunk to file content
      # @param content_lines [Array<String>] lines of file content
      # @param hunk [Hash] hunk information
      # @return [Array<String>, nil] updated content lines or nil if cannot apply
      def apply_hunk(content_lines, hunk)
        # For completely new files with no content
        if content_lines.empty? && hunk[:src_start] == 1 && hunk[:src_count] == 0
          # Just extract the added lines
          return hunk[:changes].select { |line| line.start_with?("+") }.map { |line| line[1..-1] }
        end

        # For complete file replacement
        if !content_lines.empty? &&
            hunk[:src_start] == 1 &&
            hunk[:changes].count { |line| line.start_with?("-") } >= content_lines.size
          # Get only the added lines for the new content
          return hunk[:changes].select { |line| line.start_with?("+") }.map { |line| line[1..-1] }
        end

        # Standard case with context matching
        result = content_lines.dup
        src_line = hunk[:src_start] - 1  # 0-based index
        dst_line = hunk[:dst_start] - 1  # 0-based index

        # Process each change line
        hunk[:changes].each do |line|
          if line.start_with?(" ") # Context line
            # Verify context matches
            if src_line >= result.size || result[src_line] != line[1..-1]
              # Try to find the context nearby (fuzzy matching)
              found = false
              (-3..3).each do |offset|
                check_pos = src_line + offset
                next if check_pos < 0 || check_pos >= result.size

                next unless result[check_pos] == line[1..-1]

                src_line = check_pos
                dst_line = check_pos
                found = true
                break
              end

              return nil unless found  # Context doesn't match, cannot apply hunk
            end

            src_line += 1
            dst_line += 1
          elsif line.start_with?("-")  # Removal
            # Verify line exists and matches
            if src_line >= result.size || result[src_line] != line[1..-1]
              # Try to find the line nearby (fuzzy matching)
              found = false
              (-3..3).each do |offset|
                check_pos = src_line + offset
                next if check_pos < 0 || check_pos >= result.size

                next unless result[check_pos] == line[1..-1]

                src_line = check_pos
                dst_line = check_pos
                found = true
                break
              end

              return nil unless found # Line to remove doesn't match, cannot apply hunk
            end

            # Remove the line
            result.delete_at(src_line)
          elsif line.start_with?("+") # Addition
            # Insert the new line
            result.insert(dst_line, line[1..-1])
            dst_line += 1
          end
        end

        result
      end
    end
  end
end
