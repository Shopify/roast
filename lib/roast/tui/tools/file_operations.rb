# typed: true
# frozen_string_literal: true

require "fileutils"
require "pathname"

module Roast
  module TUI
    module Tools
      class FileOperations
        # Read file tool with line numbers, image support, PDF extraction
        class Read < Base
          def initialize
            super(
              name: "read",
              description: "Read file contents with line numbers, supports images and PDFs",
              parameters: {
                type: "object",
                properties: {
                  file_path: Base.string_param("The absolute path to the file to read", required: true),
                  limit: Base.integer_param("Number of lines to read", minimum: 1),
                  offset: Base.integer_param("Line number to start reading from", minimum: 1)
                },
                required: ["file_path"]
              }
            )
          end

          def perform(arguments, context)
            path = File.expand_path(arguments["file_path"])
            
            raise ValidationError, "File not found: #{path}" unless File.exist?(path)
            raise ValidationError, "Path is a directory: #{path}" if File.directory?(path)
            
            # Handle different file types
            case File.extname(path).downcase
            when ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg"
              handle_image(path)
            when ".pdf"
              handle_pdf(path)
            else
              handle_text_file(path, arguments)
            end
          end

          private

          def handle_text_file(path, arguments)
            lines = File.readlines(path)
            offset = (arguments["offset"] || 1) - 1
            limit = arguments["limit"] || lines.length
            
            selected_lines = lines[offset, limit] || []
            
            # Format with line numbers
            result = []
            selected_lines.each_with_index do |line, idx|
              line_num = offset + idx + 1
              # Format: spaces + line number + tab + content
              result << sprintf("%6d\t%s", line_num, line.chomp)
            end
            
            if result.empty? && File.zero?(path)
              CLI::UI.puts("{{yellow:Warning: File exists but is empty}}", to: :stderr)
              return ""
            end
            
            result.join("\n")
          end

          def handle_image(path)
            # For image files, return metadata
            require "mini_magick" rescue nil
            
            if defined?(MiniMagick)
              image = MiniMagick::Image.open(path)
              "Image: #{path}\nFormat: #{image.type}\nDimensions: #{image.width}x#{image.height}\nSize: #{File.size(path)} bytes"
            else
              "Image: #{path}\nSize: #{File.size(path)} bytes\n(Install mini_magick gem for detailed image info)"
            end
          end

          def handle_pdf(path)
            # For PDF files, attempt text extraction
            begin
              require "pdf-reader"
              reader = PDF::Reader.new(path)
              text = reader.pages.map(&:text).join("\n---PAGE BREAK---\n")
              "PDF: #{path}\nPages: #{reader.page_count}\n\nContent:\n#{text}"
            rescue LoadError
              "PDF: #{path}\nSize: #{File.size(path)} bytes\n(Install pdf-reader gem for text extraction)"
            end
          end
        end

        # Write file tool with overwrite protection
        class Write < Base
          def initialize
            super(
              name: "write",
              description: "Write content to a file with overwrite protection",
              parameters: {
                type: "object",
                properties: {
                  file_path: Base.string_param("The absolute path to the file to write", required: true),
                  content: Base.string_param("The content to write to the file", required: true),
                  force: Base.boolean_param("Force overwrite if file exists", default: false)
                },
                required: ["file_path", "content"]
              },
              permission_mode: :ask
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            path = File.expand_path(arguments["file_path"])
            
            # Check if file exists and force is not set
            if File.exist?(path) && !arguments["force"]
              if context[:interactive]
                unless CLI::UI::Prompt.confirm("File #{path} exists. Overwrite?", default: false)
                  return "Write cancelled"
                end
              else
                raise ValidationError, "File exists: #{path}. Use force: true to overwrite"
              end
            end
            
            # Create directory if needed
            FileUtils.mkdir_p(File.dirname(path))
            
            # Write the file
            File.write(path, arguments["content"])
            
            "Successfully wrote #{arguments["content"].bytesize} bytes to #{path}"
          end
        end

        # Edit file tool with multiple strategies
        class Edit < Base
          def initialize
            super(
              name: "edit",
              description: "Edit files with various strategies (simple, line-based, block, regex)",
              parameters: {
                type: "object",
                properties: {
                  file_path: Base.string_param("The absolute path to the file to edit", required: true),
                  old_string: Base.string_param("The text to replace", required: true),
                  new_string: Base.string_param("The replacement text", required: true),
                  replace_all: Base.boolean_param("Replace all occurrences", default: false),
                  strategy: Base.string_param(
                    "Edit strategy", 
                    enum: ["simple", "line", "block", "regex", "whitespace_agnostic"],
                    default: "simple"
                  )
                },
                required: ["file_path", "old_string", "new_string"]
              },
              permission_mode: :ask
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            path = File.expand_path(arguments["file_path"])
            
            raise ValidationError, "File not found: #{path}" unless File.exist?(path)
            raise ValidationError, "Path is a directory: #{path}" if File.directory?(path)
            raise ValidationError, "old_string and new_string cannot be the same" if arguments["old_string"] == arguments["new_string"]
            
            content = File.read(path)
            original_content = content.dup
            
            strategy = arguments["strategy"] || "simple"
            edited_content = apply_edit_strategy(content, arguments, strategy)
            
            if edited_content == original_content
              raise ValidationError, "No matches found for '#{arguments["old_string"]}' in #{path}"
            end
            
            # Write back the edited content
            File.write(path, edited_content)
            
            # Count changes
            if arguments["replace_all"]
              count = content.scan(arguments["old_string"]).length
              "Replaced #{count} occurrences in #{path}"
            else
              "Replaced 1 occurrence in #{path}"
            end
          end

          private

          def apply_edit_strategy(content, arguments, strategy)
            old_string = arguments["old_string"]
            new_string = arguments["new_string"]
            replace_all = arguments["replace_all"]
            
            case strategy
            when "simple"
              if replace_all
                content.gsub(old_string, new_string)
              else
                content.sub(old_string, new_string)
              end
            when "line"
              apply_line_strategy(content, old_string, new_string, replace_all)
            when "block"
              apply_block_strategy(content, old_string, new_string, replace_all)
            when "regex"
              apply_regex_strategy(content, old_string, new_string, replace_all)
            when "whitespace_agnostic"
              apply_whitespace_agnostic_strategy(content, old_string, new_string, replace_all)
            else
              raise ValidationError, "Unknown strategy: #{strategy}"
            end
          end

          def apply_line_strategy(content, old_string, new_string, replace_all)
            lines = content.lines
            modified = false
            
            lines.map! do |line|
              if line.include?(old_string)
                if replace_all || !modified
                  modified = true
                  line.gsub(old_string, new_string)
                else
                  line
                end
              else
                line
              end
            end
            
            lines.join
          end

          def apply_block_strategy(content, old_string, new_string, replace_all)
            # For multi-line replacements
            if replace_all
              content.gsub(old_string, new_string)
            else
              content.sub(old_string, new_string)
            end
          end

          def apply_regex_strategy(content, old_string, new_string, replace_all)
            regex = Regexp.new(old_string)
            if replace_all
              content.gsub(regex, new_string)
            else
              content.sub(regex, new_string)
            end
          end

          def apply_whitespace_agnostic_strategy(content, old_string, new_string, replace_all)
            # Normalize whitespace for matching
            pattern = old_string.gsub(/\s+/, '\s+')
            regex = Regexp.new(pattern, Regexp::MULTILINE)
            
            if replace_all
              content.gsub(regex, new_string)
            else
              content.sub(regex, new_string)
            end
          end
        end

        # MultiEdit tool for batch edits
        class MultiEdit < Base
          def initialize
            super(
              name: "multiedit",
              description: "Perform multiple edits to a single file in one operation",
              parameters: {
                type: "object",
                properties: {
                  file_path: Base.string_param("The absolute path to the file to edit", required: true),
                  edits: Base.array_param(
                    "Array of edit operations to perform sequentially",
                    items: {
                      type: "object",
                      properties: {
                        old_string: Base.string_param("Text to replace", required: true),
                        new_string: Base.string_param("Replacement text", required: true),
                        replace_all: Base.boolean_param("Replace all occurrences", default: false)
                      },
                      required: ["old_string", "new_string"]
                    },
                    required: true
                  )
                },
                required: ["file_path", "edits"]
              },
              permission_mode: :ask
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            path = File.expand_path(arguments["file_path"])
            
            raise ValidationError, "File not found: #{path}" unless File.exist?(path)
            raise ValidationError, "Path is a directory: #{path}" if File.directory?(path)
            raise ValidationError, "No edits provided" if arguments["edits"].empty?
            
            content = File.read(path)
            original_content = content.dup
            total_changes = 0
            
            # Apply each edit in sequence
            arguments["edits"].each_with_index do |edit, index|
              old_string = edit["old_string"]
              new_string = edit["new_string"]
              replace_all = edit["replace_all"] || false
              
              raise ValidationError, "Edit #{index + 1}: old_string and new_string cannot be the same" if old_string == new_string
              
              before_edit = content.dup
              
              if replace_all
                content = content.gsub(old_string, new_string)
              else
                content = content.sub(old_string, new_string)
              end
              
              if content == before_edit
                raise ValidationError, "Edit #{index + 1}: No matches found for '#{old_string}'"
              end
              
              total_changes += 1
            end
            
            # Write back the edited content
            File.write(path, content)
            
            "Successfully applied #{total_changes} edit#{total_changes == 1 ? '' : 's'} to #{path}"
          end
        end

        # Glob tool for pattern matching
        class Glob < Base
          def initialize
            super(
              name: "glob",
              description: "Find files matching glob patterns",
              parameters: {
                type: "object",
                properties: {
                  pattern: Base.string_param("The glob pattern to match (e.g., '**/*.rb')", required: true),
                  path: Base.string_param("The directory to search in", default: "."),
                  sort: Base.string_param("Sort order", enum: ["name", "mtime", "size"], default: "name"),
                  limit: Base.integer_param("Maximum number of results", minimum: 1)
                },
                required: ["pattern"]
              }
            )
          end

          def perform(arguments, context)
            base_path = File.expand_path(arguments["path"] || ".")
            pattern = File.join(base_path, arguments["pattern"])
            
            files = Dir.glob(pattern).select { |f| File.file?(f) }
            
            # Sort files
            case arguments["sort"]
            when "mtime"
              files.sort_by! { |f| File.mtime(f) }.reverse!
            when "size"
              files.sort_by! { |f| File.size(f) }.reverse!
            else
              files.sort!
            end
            
            # Apply limit if specified
            files = files.first(arguments["limit"]) if arguments["limit"]
            
            if files.empty?
              "No files found matching pattern: #{arguments["pattern"]}"
            else
              files.map { |f| Pathname.new(f).relative_path_from(base_path).to_s }.join("\n")
            end
          end
        end

        # List directory tool
        class Ls < Base
          def initialize
            super(
              name: "ls",
              description: "List directory contents with details",
              parameters: {
                type: "object",
                properties: {
                  path: Base.string_param("The directory path", default: "."),
                  all: Base.boolean_param("Show hidden files", default: false),
                  long: Base.boolean_param("Show detailed information", default: false),
                  recursive: Base.boolean_param("List recursively", default: false),
                  sort: Base.string_param("Sort order", enum: ["name", "mtime", "size"], default: "name")
                }
              }
            )
          end

          def perform(arguments, context)
            path = File.expand_path(arguments["path"] || ".")
            
            raise ValidationError, "Path not found: #{path}" unless File.exist?(path)
            
            if File.file?(path)
              # Single file listing
              return format_file_info(path, arguments["long"])
            end
            
            entries = if arguments["recursive"]
                       Dir.glob(File.join(path, "**", "*"), File::FNM_DOTMATCH)
                     else
                       Dir.entries(path)
                     end
            
            # Filter hidden files unless --all
            unless arguments["all"]
              entries.reject! { |e| File.basename(e).start_with?(".") }
            end
            
            # Remove . and .. entries
            entries.reject! { |e| %w[. ..].include?(File.basename(e)) }
            
            # Sort entries
            entries = sort_entries(entries, arguments["sort"])
            
            # Format output
            if arguments["long"]
              entries.map { |e| format_file_info(File.join(path, e), true) }.join("\n")
            else
              entries.map { |e| File.basename(e) }.join("\n")
            end
          end

          private

          def sort_entries(entries, sort_by)
            case sort_by
            when "mtime"
              entries.sort_by { |e| File.exist?(e) ? File.mtime(e) : Time.at(0) }.reverse
            when "size"
              entries.sort_by { |e| File.exist?(e) ? File.size(e) : 0 }.reverse
            else
              entries.sort
            end
          end

          def format_file_info(path, detailed)
            return File.basename(path) unless detailed
            
            stat = File.stat(path)
            type = stat.directory? ? "d" : "-"
            perms = sprintf("%o", stat.mode & 0777)
            size = format_size(stat.size)
            mtime = stat.mtime.strftime("%Y-%m-%d %H:%M")
            name = File.basename(path)
            
            "#{type}#{perms} #{size.rjust(8)} #{mtime} #{name}"
          end

          def format_size(bytes)
            units = ["B", "K", "M", "G", "T"]
            size = bytes.to_f
            unit = 0
            
            while size >= 1024 && unit < units.length - 1
              size /= 1024
              unit += 1
            end
            
            if unit == 0
              sprintf("%d%s", size, units[unit])
            else
              sprintf("%.1f%s", size, units[unit])
            end
          end
        end

        class << self
          def register_all(registry)
            registry.register(
              name: "read",
              description: Read.new.description,
              parameters: Read.new.parameters,
              parallel_safe: true
            ) { |args| Read.new.execute(args) }

            registry.register(
              name: "write",
              description: Write.new.description,
              parameters: Write.new.parameters,
              parallel_safe: false
            ) { |args| Write.new.execute(args) }

            registry.register(
              name: "edit",
              description: Edit.new.description,
              parameters: Edit.new.parameters,
              parallel_safe: false
            ) { |args| Edit.new.execute(args) }

            registry.register(
              name: "multiedit",
              description: MultiEdit.new.description,
              parameters: MultiEdit.new.parameters,
              parallel_safe: false
            ) { |args| MultiEdit.new.execute(args) }

            registry.register(
              name: "glob",
              description: Glob.new.description,
              parameters: Glob.new.parameters,
              parallel_safe: true
            ) { |args| Glob.new.execute(args) }

            registry.register(
              name: "ls",
              description: Ls.new.description,
              parameters: Ls.new.parameters,
              parallel_safe: true
            ) { |args| Ls.new.execute(args) }
          end
        end
      end
    end
  end
end