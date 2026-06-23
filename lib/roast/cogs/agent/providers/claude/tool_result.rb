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

            #: (String | Array[Hash[Symbol, untyped]])?
            attr_reader :content

            #: bool
            attr_reader :is_error

            #: (tool_use: Messages::ToolUseMessage?, content: (String | Array[Hash[Symbol, untyped]])?, is_error: bool) -> void
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

            # Formats a Write tool-result line.
            #
            # Input: :file_path – the path that was written.
            #
            # Output: "WRITE OK <file_path>" – the file path, omitted if the
            # input has none.
            #
            # Examples:
            #   WRITE OK lib/roast/version.rb
            #   WRITE OK
            #
            #: () -> String
            def format_write
              ok_line(tool_use_input[:file_path])
            end

            # Formats an Edit tool-result line.
            #
            # Input: :file_path – the path that was edited.
            #
            # Output: "EDIT OK <file_path>" – the file path, omitted if the
            # input has none.
            #
            # Examples:
            #   EDIT OK lib/roast/version.rb
            #   EDIT OK
            #
            #: () -> String
            def format_edit
              ok_line(tool_use_input[:file_path])
            end

            # Formats a Skill tool-result line.
            #
            # Input: :skill – the name of the invoked skill.
            #
            # Output: "SKILL OK <skill>" – the skill name, omitted if the
            # input has none.
            #
            # Examples:
            #   SKILL OK commit
            #   SKILL OK
            #
            #: () -> String
            def format_skill
              ok_line(tool_use_input[:skill])
            end

            # Formats a TodoWrite tool-result line.
            #
            # Input: :todos – the todo list; each item is a hash with :status
            # ("pending"/"in_progress"/"completed"), :content, and :activeForm.
            #
            # Output: "TODOWRITE OK <done>/<total> done · <active>" – the
            # completed count over the total, then the in-progress item's
            # :activeForm (or :content), truncated. The " · <active>" part is
            # omitted when nothing is in progress; an empty list yields a bare
            # "TODOWRITE OK".
            #
            # Examples:
            #   TODOWRITE OK 3/8 done · Implementing the parser
            #   TODOWRITE OK 8/8 done
            #   TODOWRITE OK
            #
            #: () -> String
            def format_todowrite
              todos = tool_use_input[:todos] || []
              done = todos.count { |todo| todo[:status] == "completed" }
              active = todos.find { |todo| todo[:status] == "in_progress" }
              progress = "#{done}/#{todos.length} done" if todos.any?
              active_label = truncate(active[:activeForm] || active[:content]) if active
              ok_line(progress, active_label)
            end

            # Formats a TaskUpdate tool-result line.
            #
            # Content: the text the tool returned.
            #
            # Output: "TASKUPDATE OK <preview>" – the first line of content,
            # stripped and truncated to TRUNCATE_LIMIT chars. The preview is
            # omitted when there is no content.
            #
            # Examples:
            #   TASKUPDATE OK Task updated successfully
            #   TASKUPDATE OK
            #
            #: () -> String
            def format_taskupdate
              preview = truncate(content.to_s.lines.first.to_s.strip)
              ok_line(preview)
            end

            # Formats a TaskCreate tool-result line.
            #
            # Content: the text the tool returned.
            #
            # Output: "TASKCREATE OK <preview>" – the first line of content,
            # stripped and truncated to TRUNCATE_LIMIT chars. The preview is
            # omitted when there is no content.
            #
            # Examples:
            #   TASKCREATE OK Task created successfully
            #   TASKCREATE OK
            #
            #: () -> String
            def format_taskcreate
              preview = truncate(content.to_s.lines.first.to_s.strip)
              ok_line(preview)
            end

            # Formats an Agent tool-result line.
            #
            # Content: the subagent's final message, delivered as a list of
            # content blocks and joined into text.
            #
            # Output: "AGENT OK <preview>" – the first line of that text,
            # stripped and truncated to TRUNCATE_LIMIT chars. The preview is
            # omitted when there is no content.
            #
            # Examples:
            #   AGENT OK Refactored the parser; all tests pass
            #   AGENT OK Migrated the user table and backfilled all...
            #   AGENT OK
            #
            #: () -> String
            def format_agent
              preview = truncate(normalize_content(content).lines.first.to_s.strip)
              ok_line(preview)
            end

            # Formats a Task tool-result line.
            #
            # Content: the dispatched subagent's reply, or a launch notice
            # when the run is backgrounded – delivered as a list of content
            # blocks and joined into text.
            #
            # Output: "TASK OK <preview>" – the first line of that text,
            # stripped and truncated to TRUNCATE_LIMIT chars. The preview is
            # omitted when there is no content.
            #
            # Examples:
            #   TASK OK Async agent launched successfully
            #   TASK OK Migrated the user table and backfilled all...
            #   TASK OK
            #
            #: () -> String
            def format_task
              preview = truncate(normalize_content(content).lines.first.to_s.strip)
              ok_line(preview)
            end

            # Formats a TaskOutput tool-result line.
            #
            # Content: sibling tags carrying the task's state, followed by a
            # trailing <output> of arbitrary unescaped text. A pull parser reads
            # only as far as the status tag, so the absent single root and the
            # unescaped <output> body are never reached.
            #
            # Output: "TASKOUTPUT OK <status>" – the text of <status>, or of
            # <retrieval_status> when no <status> tag is present (as on a
            # pending retrieval). The status is omitted when neither is present.
            #
            # Examples:
            #   TASKOUTPUT OK completed
            #   TASKOUTPUT OK pending
            #   TASKOUTPUT OK
            #
            #: () -> String
            def format_taskoutput
              ok_line(tag_text("status") || tag_text("retrieval_status"))
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

            # The result's text. Agent and Task deliver a list of content
            # blocks, which is joined into a string; every other shape is
            # coerced with to_s.
            #
            #: ((String | Array[Hash[Symbol, untyped]])?) -> String
            def normalize_content(value)
              case value
              when String
                value
              when Array
                value.filter_map { |b| b[:text] }.join("\n")
              else
                value.to_s
              end
            end

            # Pull-parses `source` and returns the stripped text of the first
            # <tag> element, or nil when absent. Parsing stops as soon as the
            # tag is found, so a malformed tail (such as an unescaped <output>
            # body) is never reached, and a parse error yields nil.
            #
            # Only suitable for tags whose body is plain text: the parser treats
            # `<` as markup, so it cannot extract a body that itself contains
            # angle brackets (e.g. an error message).
            #
            #: (String, ?String) -> String?
            def tag_text(tag, source = content.to_s)
              parser = REXML::Parsers::PullParser.new(source)
              current = nil #: String?
              while parser.has_next?
                event = parser.pull
                if event.start_element?
                  current = event[0]
                elsif event.end_element?
                  current = nil
                elsif event.text? && current == tag
                  return event[0].strip
                end
              end
              nil
            rescue REXML::ParseException
              nil
            end
          end
        end
      end
    end
  end
end
