# typed: true
# frozen_string_literal: true

require "nokogiri"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          class ToolResult
            #: Symbol?
            attr_reader :tool_name

            #: String?
            attr_reader :tool_use_description

            # The originating tool-use input, so a result line can echo an identifier
            # (file path, task id, …) that ties it back to its call when the two lines
            # are not adjacent. Empty hash when there is no tool_use.
            #: Hash[Symbol, untyped]
            attr_reader :tool_use_input

            # Usually the raw result string; the Agent tool returns an array of content
            # blocks ({ type:, text: }) on success.
            #: (String | Array[untyped])?
            attr_reader :content

            #: bool
            attr_reader :is_error

            #: (tool_use: Messages::ToolUseMessage?, content: (String | Array[untyped])?, is_error: bool) -> void
            def initialize(tool_use:, content:, is_error:)
              @tool_name = tool_use&.name || :unknown
              @tool_use_description = tool_use&.input&.fetch(:description, nil) #: String?
              @tool_use_input = tool_use&.input || {} #: Hash[Symbol, untyped]
              @content = content
              @is_error = is_error
            end

            #: () -> String
            def format
              format_method_name = "format_#{tool_name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            # A result line only ever needs a short peek at the content; matches the
            # tool-use side's limit.
            TRUNCATE_LIMIT = 45

            private

            # --- success formatters -------------------------------------------------
            # Each renders one line, "<TOOL> OK[ <summary>]". The summary shows the
            # *outcome* the tool-use line could not — output, a count, or a preview —
            # and is omitted for tools whose use line already told the whole story.
            # Every formatter defers to #error_line when is_error is set.
            #
            #
            #
            # Notes: link tool result to tool call for easier reading.
            # Clear distinction between tool use and tool result.

            # Bash: contents is the command output. We show a preview of the first line
            # of output. We also show how manny lines the output has.
            #: () -> String
            def format_bash
              return error_line if is_error

              lines = content.to_s.lines
              preview = truncate(lines.first.to_s.strip)
              "BASH OK #{lines.length} #{lines.length == 1 ? "line" : "lines"} · #{preview}"
            end

            # Read: content has the file's content. No need to show it as the
            # tool use already shows the file path and line range. We just need to
            # show how many lines were read as confirmation.
            #: () -> String
            def format_read
              return error_line if is_error

              n = content.to_s.chomp.lines.length
              "READ OK #{n} #{n == 1 ? "line" : "lines"}"
            end

            # Glob: newline-separated absolute file paths; every path line starts with "/".
            # Any other line is a non-success message (the no-match sentinel, a truncation
            # notice, etc.) — left open-ended rather than enumerated. We report the number
            # of path lines and, when paths were found, append the message as a trailing
            # NOTE. A zero-result run drops the NOTE — "0 files found" already says it.
            #: () -> String
            def format_glob
              return error_line if is_error

              lines = content.to_s.lines.map(&:strip).reject(&:empty?)
              files, notes = lines.partition { |line| line.start_with?("/") }
              summary = "GLOB OK #{files.length} #{"file".pluralize(files.length)} found"
              return summary if files.empty? || notes.empty?

              "#{summary} NOTE #{truncate(notes.join(" "))}"
            end

            # Grep: match lines mixed with the occasional system note. Like Glob, but a
            # match has no single prefix — so a line counts as a match when it holds a
            # path ("/") or a "<line>:" locator (the "12:" in "file:12:text" or a bare
            # "12:text"). A note never holds one: its only colons are "key: value" pairs
            # (colon-space), so "Found 132 files limit: 30, offset: 0" stays a note.
            # Notes are left open-ended (the sentinel, a "Found N files" header, a
            # "[Showing ...]" notice). The note rides along when matches were found; a
            # zero-match run drops it — "0 matches" already says it.
            #: () -> String
            def format_grep
              return error_line if is_error

              lines = content.to_s.lines.map(&:strip).reject(&:empty?)
              matches, notes = lines.partition { |line| line.include?("/") || line.match?(/\d:/) }
              summary = "GREP OK #{matches.length} #{"match".pluralize(matches.length)}"
              return summary if matches.empty? || notes.empty?

              "#{summary} NOTE #{truncate(notes.join(" "))}"
            end

            # Write/Edit: confirm the operation and echo :file_path — the identifier the
            # use line led with — so the two pair up even when far apart. Bare OK when
            # the path is somehow absent.
            #: () -> String
            def format_write
              return error_line if is_error

              path = tool_use_input[:file_path]
              path ? "WRITE OK #{path}" : "WRITE OK"
            end

            #: () -> String
            def format_edit
              return error_line if is_error

              path = tool_use_input[:file_path]
              path ? "EDIT OK #{path}" : "EDIT OK"
            end

            # Skill: echo :skill, the name of the invoked skill (the use line's subject).
            #: () -> String
            def format_skill
              return error_line if is_error

              skill = tool_use_input[:skill]
              skill ? "SKILL OK #{skill}" : "SKILL OK"
            end

            # TodoWrite: the list carries no id, so surface progress instead. While a
            # todo is in_progress, show its activeForm — the live "doing X" label the
            # use line's status counts don't carry; once none is, show the
            # completed/total count as closure. Empty list -> bare OK.
            #: () -> String
            def format_todowrite
              return error_line if is_error

              todos = tool_use_input[:todos] || []
              return "TODOWRITE OK" if todos.empty?

              active = todos.find { |todo| todo[:status] == "in_progress" }
              return "TODOWRITE OK → #{active[:activeForm] || active[:content]}" if active

              done = todos.count { |todo| todo[:status] == "completed" }
              "TODOWRITE OK #{done}/#{todos.length} done"
            end

            # TaskUpdate: confirmation of a status change. Its schema and wording are
            # unverified — absent from the sample log — so preview the line as-is rather
            # than assert taskId/status fields we'd only be guessing at, as Bash/Agent do.
            #: () -> String
            def format_taskupdate
              return error_line if is_error

              preview = truncate(content.to_s.lines.first.to_s.strip)
              preview.empty? ? "TASKUPDATE OK" : "TASKUPDATE OK #{preview}"
            end

            # TaskCreate: the result is a short confirmation that names the newly
            # assigned id (the key a later TaskUpdate references). Its exact wording is
            # unverified — absent from the sample log — so preview the line as-is rather
            # than parse a format we'd only be guessing at, as Bash/Agent do.
            #: () -> String
            def format_taskcreate
              return error_line if is_error

              preview = truncate(content.to_s.lines.first.to_s.strip)
              preview.empty? ? "TASKCREATE OK" : "TASKCREATE OK #{preview}"
            end

            # TaskOutput: sibling tags carrying the task's state, with a trailing
            # <output> of arbitrary unescaped text. Parse leniently as a fragment
            # (no single root, tolerates the unescaped <output>) and surface
            # <status> — a pending retrieval carries only <retrieval_status>.
            #: () -> String
            def format_taskoutput
              return error_line if is_error

              fragment = Nokogiri::XML::DocumentFragment.parse(content.to_s)
              status = (fragment.at_xpath(".//status") || fragment.at_xpath(".//retrieval_status"))&.text&.strip
              status ? "TASKOUTPUT OK #{status}" : "TASKOUTPUT OK"
            end

            # Agent: subagent output — an array of { type:, text: } blocks on success.
            #: () -> String
            def format_agent
              return error_line if is_error

              preview = truncate(agent_text(content).lines.first.to_s.strip)
              preview.empty? ? "AGENT OK" : "AGENT OK #{preview}"
            end

            # Task: like Agent (subagent output). Not exercised in the sample log, so the
            # array handling here is by analogy with Agent.
            #: () -> String
            def format_task
              return error_line if is_error

              preview = truncate(agent_text(content).lines.first.to_s.strip)
              preview.empty? ? "TASK OK" : "TASK OK #{preview}"
            end

            #: () -> String
            def format_unknown
              "UNKNOWN [#{tool_name}] #{is_error ? " ERROR" : "OK"} #{tool_use_description || ""}\n#{content}"
            end

            # --- helpers ------------------------------------------------------------

            # Uniform error line: "<TOOL> ERROR <message>", with any <tool_use_error>
            # wrapper stripped (a no-op on the tools that send a plain string).
            #: () -> String
            def error_line
              message = content.to_s.gsub(%r{</?tool_use_error>}, "").lines.first.to_s.strip
              "#{tool_name.to_s.upcase} ERROR #{message}"
            end

            # Subagent content is an array of { text: } blocks (or a plain string).
            #: (untyped) -> String
            def agent_text(value)
              return value.to_s unless value.is_a?(Array)

              value.filter_map { |b| b.is_a?(Hash) ? (b[:text] || b["text"]) : b }.join("\n")
            end

            # Truncates to TRUNCATE_LIMIT chars, appending "..." when cut. nil -> "".
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
