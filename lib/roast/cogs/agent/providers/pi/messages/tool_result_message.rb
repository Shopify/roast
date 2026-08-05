# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Represents a tool execution result from the Pi agent
            #
            # In Pi's JSON protocol, tool results appear as `tool_execution_end` events
            # containing the result content and error status.
            class ToolResultMessage
              #: String?
              attr_reader :tool_call_id

              #: String?
              attr_reader :tool_name

              #: String?
              attr_reader :content

              #: bool
              attr_reader :is_error

              #: (tool_call_id: String?, tool_name: String?, content: String?, is_error: bool) -> void
              def initialize(tool_call_id:, tool_name:, content:, is_error:)
                @tool_call_id = tool_call_id
                @tool_name = tool_name
                @content = content
                @is_error = is_error
                @name = (tool_name || "unknown").to_s #: String
                @input = {} #: Hash[Symbol, untyped]
              end

              #: (PiInvocation::Context) -> String?
              def format(context)
                call = context.tool_call(tool_call_id)
                @name = (tool_name || call&.name || "unknown").to_s
                @input = call&.arguments || {}

                return error_line if is_error

                format_method_name = "format_#{@name.downcase}".to_sym
                return send(format_method_name) if respond_to?(format_method_name, true)

                format_unknown
              rescue StandardError
                format_unknown
              end

              # Truncates each element in a formatted tool-result string to keep terminal output concise.
              TRUNCATE_LIMIT = 45

              private

              # Formats a bash tool result.
              #
              # Content: the command's output text.
              #
              # Output: "BASH OK <n> <line|lines> · <preview>" – <n> is the line count
              # (pluralized) and <preview> is the first line, stripped and truncated to
              # TRUNCATE_LIMIT chars. The preview is omitted when there is no output.
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

              # Formats a read tool result.
              #
              # Content: the file's text.
              #
              # Output: "READ OK <n> <line|lines>" – <n> is the file's line count
              # (pluralized). Blank lines are counted: this is the file's own length, so
              # it deliberately differs from entry-listing tools (find/ls), which drop
              # blanks because a blank isn't an entry.
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

              # Formats a write tool result.
              #
              # Input: :path – the path that was written, from the originating call.
              #
              # Output: "WRITE OK <path>" – the file path, omitted when the call
              # had none.
              #
              # Examples:
              #   WRITE OK lib/roast/version.rb
              #   WRITE OK
              #
              #: () -> String
              def format_write
                ok_line(@input[:path])
              end

              # Formats an edit tool result.
              #
              # Input: :path – the path that was edited, from the originating call.
              #
              # Output: "EDIT OK <path>" – the file path, omitted when the call
              # had none.
              #
              # Examples:
              #   EDIT OK lib/roast/version.rb
              #   EDIT OK
              #
              #: () -> String
              def format_edit
                ok_line(@input[:path])
              end

              # Formats a grep tool result.
              #
              # Content: matching lines, and possibly informational notes, one per
              # line.
              #
              # Output: "GREP OK <n> <match|matches>[ · NOTE <notes>]" – <n> counts
              # lines that look like matches (a leading path or line-number prefix);
              # any remaining lines are joined into a truncated NOTE, shown only when
              # there are both matches and notes.
              #
              # Examples:
              #   GREP OK 3 matches
              #   GREP OK 1 match
              #   GREP OK 0 matches
              #
              #: () -> String
              def format_grep
                lines = content.to_s.lines.map(&:strip).reject(&:empty?)
                matches, notes = lines.partition { |line| line.match?(%r{\A\S+/}) || line.match?(/\A(?:\S+:)?\d+:/) }
                count = matches.length
                note = "NOTE #{truncate(notes.join(" "))}" if matches.any? && notes.any?
                ok_line("#{count} #{"match".pluralize(count)}", note)
              end

              # Formats a find tool result.
              #
              # Content: matching paths, one per line, plus an optional status line –
              # either a bracketed notice ("[2 results limit reached. ...]") or the
              # no-results prose ("No files found matching pattern").
              #
              # Output: "FIND OK <n> <path|paths>[ · NOTE <status>]" – <n> counts the
              # path lines only, and the notice's brackets are dropped. As in #format_grep,
              # the NOTE is shown only alongside results: "0 paths" already says what the
              # no-results prose would.
              #
              # Examples:
              #   FIND OK 12 paths
              #   FIND OK 1 path
              #   FIND OK 2 paths · NOTE 2 results limit reached. Use limit=4 for m...
              #   FIND OK 0 paths
              #
              #: () -> String
              def format_find
                lines = content.to_s.lines.map(&:strip).reject(&:empty?)
                notes, paths = lines.partition { |line| line.sub!(/\A\[(.*)\]\z/, '\1') || line.match?(/\ANo files found/) }
                count = paths.length
                note = "NOTE #{truncate(notes.join(" "))}" if paths.any? && notes.any?
                ok_line("#{count} #{"path".pluralize(count)}", note)
              end

              # Formats a result for which Roast has no dedicated formatter.
              #
              # Content: the tool's output text.
              #
              # Output: "<NAME> OK <preview>" – the first line of content, stripped and
              # truncated to TRUNCATE_LIMIT chars. The preview is omitted when there is
              # no content.
              #
              # Examples:
              #   WEB_SEARCH OK 3 results for "ruby pluralize"
              #   DEPLOY OK
              #
              #: () -> String
              def format_unknown
                preview = truncate(content.to_s.lines.first.to_s.strip)
                ok_line(preview)
              end

              # Renders "<TOOL> OK[ <part> · <part> · ...]"; the success-side twin of
              # #error_line. Blank/nil parts are dropped and the rest joined with " · ",
              # so callers pass each piece of the summary without minding separators.
              #
              #: (*String?) -> String
              def ok_line(*parts)
                summary = parts.select(&:present?).join(" · ")
                prefix = "#{@name.upcase} OK"
                summary.present? ? "#{prefix} #{summary}" : prefix
              end

              # Renders "<TOOL> ERROR <message>". The content is shown as-is and intentionally not truncated,
              # preserving the full diagnostic.
              #
              # Examples:
              #   READ ERROR ENOENT: no such file or directory
              #
              #: () -> String
              def error_line
                "#{@name.upcase} ERROR #{content.to_s.strip}".strip
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
end
