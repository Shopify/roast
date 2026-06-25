# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ToolResult
            #: Symbol?
            attr_reader :tool_name

            #: Hash[Symbol, untyped]
            attr_reader :tool_use_input

            #: String?
            attr_reader :tool_use_description

            #: String?
            attr_reader :content

            #: bool
            attr_reader :is_error

            #: (tool_use: Messages::ToolUseMessage?, content: String?, is_error: bool) -> void
            def initialize(tool_use:, content:, is_error:)
              @tool_name = tool_use&.name || :unknown
              @tool_use_input = tool_use&.input || {} #: Hash[Symbol, untyped]
              @tool_use_description = @tool_use_input[:description] #: String?
              @content = content
              @is_error = is_error
            end

            #: () -> String
            def format
              return error_line if is_error

              format_method_name = "format_#{tool_name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            TRUNCATE_LIMIT = 45

            private

            # Formats a Bash tool-result line.
            #
            # Content: the command's combined stdout/stderr, as a string.
            #
            # Output: "BASH OK <n> <line|lines> · <preview>" – <n> is the number of
            # output lines (pluralized), and <preview> is the first line, stripped and
            # truncated to TRUNCATE_LIMIT chars. The " · <preview>" suffix is omitted
            # when the command produced no output.
            #
            # Examples:
            #   BASH OK 12 lines · Cloning into 'roast'...
            #   BASH OK 1 line · hello world
            #   BASH OK 0 lines
            #
            #: () -> String
            def format_bash
              lines = content.to_s.lines
              count = lines.length
              preview = truncate(lines.first.to_s.strip)
              ok_line("#{count} #{"line".pluralize(count)}", preview)
            end

            # Formats a Read tool-result line.
            #
            # Content: the file's contents, as a string.
            #
            # Output: "READ OK <n> <line|lines>" – <n> is the number of lines
            # read, pluralized.
            #
            # Examples:
            #   READ OK 42 lines
            #   READ OK 1 line
            #   READ OK 0 lines
            #
            #: () -> String
            def format_read
              count = content.to_s.lines.length
              ok_line("#{count} #{"line".pluralize(count)}")
            end

            # Formats a Glob tool-result line.
            #
            # Content: newline-separated matches. Lines starting with "/" are
            # file paths; any other line is a status message (a no-match
            # sentinel, a truncation notice, etc.).
            #
            # Output: "GLOB OK <n> <file|files> found" – <n> is the number of
            # path lines. When paths were found and a status message is present,
            # it is appended as a truncated "NOTE <message>" part. A zero-result
            # run omits the NOTE.
            #
            # Examples:
            #   GLOB OK 12 files found
            #   GLOB OK 1 file found
            #   GLOB OK 0 files found
            #   GLOB OK 8 files found · NOTE Results truncated...
            #
            #: () -> String
            def format_glob
              lines = content.to_s.lines.map(&:strip).reject(&:empty?)
              files, notes = lines.partition { |line| line.start_with?("/") }
              count = files.length
              note = "NOTE #{truncate(notes.join(" "))}" if files.any? && notes.any?
              ok_line("#{count} #{"file".pluralize(count)} found", note)
            end

            # Formats a Grep tool-result line.
            #
            # Content: newline-separated results. A line is a match when it
            # starts with either a path segment containing "/" (a bare path or
            # path:line:content), or an optional "file:" prefix followed by a
            # "<digits>:" line number (line:content in single-file mode, or
            # path:line:content for a root-level file with no "/"). Any other
            # line is a status message (a no-match sentinel, a truncation
            # notice, etc.).
            #
            # Output: "GREP OK <n> <match|matches>" – <n> is the number of match
            # lines. When matches were found and a status message is present, it
            # is appended as a truncated "NOTE <message>" part. A zero-result run
            # omits the NOTE.
            #
            # Examples:
            #   GREP OK 12 matches
            #   GREP OK 1 match
            #   GREP OK 0 matches
            #   GREP OK 8 matches · NOTE Results truncated...
            #
            #: () -> String
            def format_grep
              lines = content.to_s.lines.map(&:strip).reject(&:empty?)
              matches, notes = lines.partition { |line| line.match?(%r{\A\S+/}) || line.match?(/\A(?:\S+:)?\d+:/) }
              count = matches.length
              note = "NOTE #{truncate(notes.join(" "))}" if matches.any? && notes.any?
              ok_line("#{count} #{"match".pluralize(count)}", note)
            end

            #: () -> String
            def format_unknown
              "UNKNOWN [#{tool_name}] OK #{tool_use_description}\n#{content}"
            end

            # Renders "<TOOL> OK[ <part> · <part> · ...]"; the success-side twin of
            # #error_line. Blank/nil parts are dropped and the rest joined with " · ",
            # so callers pass each piece of the summary without minding separators.
            #
            #: (*String?) -> String
            def ok_line(*parts)
              summary = parts.select(&:present?).join(" · ")
              prefix = "#{tool_name.to_s.upcase} OK"
              summary.present? ? "#{prefix} #{summary}" : prefix
            end

            # Renders "<TOOL> ERROR <message>" with any <tool_use_error> wrapper stripped.
            #
            # Reads the instance's `content` and `tool_name` to produce a single-line
            # error summary. Error messages are intentionally NOT truncated so the full
            # diagnostic is preserved for debugging.
            #
            # Examples:
            #   BASH ERROR File has not been read yet.
            #   UNKNOWN ERROR command not found
            #
            #: () -> String
            def error_line
              message = content.to_s.gsub(%r{</?tool_use_error>}, "").strip
              "#{tool_name.to_s.upcase} ERROR #{message}".strip
            end

            # Truncates to TRUNCATE_LIMIT chars, appending "..." when cut. nil -> "".
            #
            #: (String?) -> String
            def truncate(str)
              s = str.to_s
              s.length > TRUNCATE_LIMIT ? "#{s[0...TRUNCATE_LIMIT - 3]}..." : s
            end
          end
        end
      end
    end
  end
end
