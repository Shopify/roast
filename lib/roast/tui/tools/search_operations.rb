# typed: true
# frozen_string_literal: true

require "open3"
require "shellwords"

module Roast
  module TUI
    module Tools
      class SearchOperations
        # Grep tool using ripgrep for fast searching
        class Grep < Base
          def initialize
            super(
              name: "grep",
              description: "Search file contents using ripgrep with regex support",
              parameters: {
                type: "object",
                properties: {
                  pattern: Base.string_param("The regex pattern to search for", required: true),
                  path: Base.string_param("File or directory to search", default: "."),
                  glob: Base.string_param("Glob pattern to filter files (e.g., '*.rb')"),
                  type: Base.string_param("File type to search (e.g., 'ruby', 'js')"),
                  output_mode: Base.string_param(
                    "Output format",
                    enum: ["content", "files_with_matches", "count"],
                    default: "files_with_matches"
                  ),
                  case_insensitive: Base.boolean_param("Case insensitive search", default: false),
                  multiline: Base.boolean_param("Enable multiline matching", default: false),
                  context_before: Base.integer_param("Lines to show before match", minimum: 0),
                  context_after: Base.integer_param("Lines to show after match", minimum: 0),
                  context: Base.integer_param("Lines to show before and after match", minimum: 0),
                  line_numbers: Base.boolean_param("Show line numbers", default: true),
                  head_limit: Base.integer_param("Limit output to first N results", minimum: 1),
                  invert_match: Base.boolean_param("Show lines that don't match", default: false)
                },
                required: ["pattern"]
              }
            )
          end

          def perform(arguments, context)
            # Check if ripgrep is available
            unless command_available?("rg")
              return fallback_grep(arguments)
            end
            
            cmd_args = build_ripgrep_command(arguments)
            execute_ripgrep(cmd_args, arguments)
          end

          private

          def command_available?(cmd)
            system("which #{cmd} > /dev/null 2>&1")
          end

          def build_ripgrep_command(arguments)
            cmd = ["rg"]
            
            # Add flags based on arguments
            cmd << "-i" if arguments["case_insensitive"]
            cmd << "-U" << "--multiline-dotall" if arguments["multiline"]
            cmd << "-v" if arguments["invert_match"]
            
            # Output mode
            case arguments["output_mode"]
            when "files_with_matches"
              cmd << "-l"
            when "count"
              cmd << "-c"
            when "content"
              cmd << "-n" if arguments["line_numbers"]
            end
            
            # Context lines
            if arguments["context"]
              cmd << "-C" << arguments["context"].to_s
            else
              cmd << "-B" << arguments["context_before"].to_s if arguments["context_before"]
              cmd << "-A" << arguments["context_after"].to_s if arguments["context_after"]
            end
            
            # File filtering
            cmd << "--glob" << arguments["glob"] if arguments["glob"]
            cmd << "--type" << arguments["type"] if arguments["type"]
            
            # Pattern and path
            cmd << "--" << arguments["pattern"]
            cmd << File.expand_path(arguments["path"] || ".")
            
            cmd
          end

          def execute_ripgrep(cmd_args, arguments)
            stdout, stderr, status = Open3.capture3(*cmd_args.map(&:to_s))
            
            if !status.success? && !stderr.empty?
              if stderr.include?("No such file or directory")
                raise ValidationError, "Path not found: #{arguments["path"]}"
              elsif stderr.include?("regex parse error")
                raise ValidationError, "Invalid regex pattern: #{arguments["pattern"]}"
              end
            end
            
            results = stdout.strip
            
            # Apply head limit if specified
            if arguments["head_limit"] && !results.empty?
              lines = results.lines
              results = lines.first(arguments["head_limit"]).join
            end
            
            results.empty? ? "No matches found" : results
          end

          def fallback_grep(arguments)
            # Fallback to standard grep if ripgrep is not available
            cmd = ["grep"]
            cmd << "-i" if arguments["case_insensitive"]
            cmd << "-l" if arguments["output_mode"] == "files_with_matches"
            cmd << "-c" if arguments["output_mode"] == "count"
            cmd << "-n" if arguments["line_numbers"] && arguments["output_mode"] == "content"
            cmd << "-r" if File.directory?(File.expand_path(arguments["path"] || "."))
            cmd << "-v" if arguments["invert_match"]
            
            # Context lines
            if arguments["context"]
              cmd << "-C" << arguments["context"].to_s
            else
              cmd << "-B" << arguments["context_before"].to_s if arguments["context_before"]
              cmd << "-A" << arguments["context_after"].to_s if arguments["context_after"]
            end
            
            pattern = Shellwords.escape(arguments["pattern"])
            path = Shellwords.escape(File.expand_path(arguments["path"] || "."))
            
            cmd << pattern << path
            
            stdout, stderr, status = Open3.capture3(cmd.join(" "))
            
            if !status.success? && !stderr.include?("No such file")
              return "No matches found"
            end
            
            results = stdout.strip
            
            # Apply head limit if specified
            if arguments["head_limit"] && !results.empty?
              lines = results.lines
              results = lines.first(arguments["head_limit"]).join
            end
            
            results.empty? ? "No matches found" : results
          end
        end

        # Find tool for locating files by name
        class Find < Base
          def initialize
            super(
              name: "find",
              description: "Find files by name or path patterns",
              parameters: {
                type: "object",
                properties: {
                  pattern: Base.string_param("Name pattern to search for (supports wildcards)", required: true),
                  path: Base.string_param("Directory to search in", default: "."),
                  type: Base.string_param("File type", enum: ["file", "directory", "any"], default: "any"),
                  max_depth: Base.integer_param("Maximum depth to search", minimum: 1),
                  min_size: Base.string_param("Minimum file size (e.g., '1M', '100K')"),
                  max_size: Base.string_param("Maximum file size (e.g., '10M', '1G')"),
                  modified_within: Base.string_param("Files modified within time (e.g., '7d', '24h')"),
                  case_insensitive: Base.boolean_param("Case insensitive search", default: false),
                  regex: Base.boolean_param("Treat pattern as regex", default: false),
                  limit: Base.integer_param("Maximum number of results", minimum: 1)
                },
                required: ["pattern"]
              }
            )
          end

          def perform(arguments, context)
            base_path = File.expand_path(arguments["path"] || ".")
            
            raise ValidationError, "Path not found: #{base_path}" unless File.exist?(base_path)
            
            if command_available?("fd")
              execute_fd(arguments, base_path)
            else
              execute_find(arguments, base_path)
            end
          end

          private

          def command_available?(cmd)
            system("which #{cmd} > /dev/null 2>&1")
          end

          def execute_fd(arguments, base_path)
            cmd = ["fd"]
            
            # Add options
            cmd << "-i" if arguments["case_insensitive"]
            cmd << "--max-depth" << arguments["max_depth"].to_s if arguments["max_depth"]
            
            # File type
            case arguments["type"]
            when "file"
              cmd << "--type" << "f"
            when "directory"
              cmd << "--type" << "d"
            end
            
            # Size filters
            cmd << "--size" << ">" + arguments["min_size"] if arguments["min_size"]
            cmd << "--size" << "<" + arguments["max_size"] if arguments["max_size"]
            
            # Modified time
            if arguments["modified_within"]
              cmd << "--changed-within" << arguments["modified_within"]
            end
            
            # Pattern and path
            pattern = arguments["regex"] ? arguments["pattern"] : glob_to_regex(arguments["pattern"])
            cmd << pattern << base_path
            
            stdout, stderr, status = Open3.capture3(*cmd.map(&:to_s))
            
            format_find_results(stdout, arguments["limit"], base_path)
          end

          def execute_find(arguments, base_path)
            cmd = ["find", base_path]
            
            # Max depth
            cmd << "-maxdepth" << arguments["max_depth"].to_s if arguments["max_depth"]
            
            # File type
            case arguments["type"]
            when "file"
              cmd << "-type" << "f"
            when "directory"
              cmd << "-type" << "d"
            end
            
            # Name pattern
            if arguments["regex"]
              cmd << "-regex" << arguments["pattern"]
            elsif arguments["case_insensitive"]
              cmd << "-iname" << arguments["pattern"]
            else
              cmd << "-name" << arguments["pattern"]
            end
            
            # Size filters
            if arguments["min_size"]
              cmd << "-size" << "+" + normalize_size(arguments["min_size"])
            end
            if arguments["max_size"]
              cmd << "-size" << "-" + normalize_size(arguments["max_size"])
            end
            
            # Modified time
            if arguments["modified_within"]
              days = parse_time_to_days(arguments["modified_within"])
              cmd << "-mtime" << "-#{days}"
            end
            
            stdout, stderr, status = Open3.capture3(*cmd.map(&:to_s))
            
            format_find_results(stdout, arguments["limit"], base_path)
          end

          def glob_to_regex(pattern)
            # Convert glob pattern to regex for fd
            pattern.gsub("*", ".*").gsub("?", ".")
          end

          def normalize_size(size_str)
            # Convert human-readable size to find format
            match = size_str.match(/^(\d+)([KMG])?$/i)
            return size_str unless match
            
            number = match[1].to_i
            unit = match[2]&.upcase
            
            case unit
            when "K"
              "#{number}k"
            when "M"
              "#{number}M"
            when "G"
              "#{number}G"
            else
              "#{number}c"
            end
          end

          def parse_time_to_days(time_str)
            match = time_str.match(/^(\d+)([dhm])$/i)
            return 1 unless match
            
            number = match[1].to_i
            unit = match[2].downcase
            
            case unit
            when "d"
              number
            when "h"
              (number / 24.0).ceil
            when "m"
              (number / (24.0 * 60)).ceil
            else
              number
            end
          end

          def format_find_results(output, limit, base_path)
            lines = output.strip.lines.map(&:strip).reject(&:empty?)
            
            return "No files found matching criteria" if lines.empty?
            
            # Apply limit if specified
            lines = lines.first(limit) if limit
            
            # Make paths relative to base_path if possible
            lines.map do |path|
              begin
                Pathname.new(path).relative_path_from(base_path).to_s
              rescue
                path
              end
            end.join("\n")
          end
        end

        class << self
          def register_all(registry)
            registry.register(
              name: "grep",
              description: Grep.new.description,
              parameters: Grep.new.parameters,
              parallel_safe: true
            ) { |args| Grep.new.execute(args) }

            registry.register(
              name: "find",
              description: Find.new.description,
              parameters: Find.new.parameters,
              parallel_safe: true
            ) { |args| Find.new.execute(args) }
          end
        end
      end
    end
  end
end