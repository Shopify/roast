# typed: true
# frozen_string_literal: true

require "nokogiri"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          # DRY prototype of ToolResult — same rendered output, organized for
          # least repetition rather than per-formatter explicitness. The error
          # branch lives once in #format; #ok builds the "<TOOL> OK[ summary]"
          # shape for everyone; preview/echo formatters collapse to one-liners;
          # identical tools share a body via alias_method.
          #
          # Trade-off vs ToolResult: less code and one place to change the line
          # shape, but behavior is spread across helpers (read format_grep plus
          # #list_summary plus #ok) and the per-tool "why" comments are gone.
          class ToolResultDry
            #: Symbol?
            attr_reader :tool_name

            #: String?
            attr_reader :tool_use_description

            #: Hash[Symbol, untyped]
            attr_reader :tool_use_input

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

            # A result line only ever needs a short peek at the content.
            TRUNCATE_LIMIT = 45

            #: () -> String
            def format
              return error_line if is_error

              method = "format_#{tool_name}".to_sym
              respond_to?(method, true) ? send(method) : format_unknown
            end

            private

            # --- success formatters -------------------------------------------------

            def format_bash
              lines = content.to_s.lines
              ok("#{lines.length} #{"line".pluralize(lines.length)} · #{preview_line(content)}")
            end

            def format_read
              n = content.to_s.chomp.lines.length
              ok("#{n} #{"line".pluralize(n)}")
            end

            def format_glob = list_summary("file", found: true) { |line| line.start_with?("/") }
            def format_grep = list_summary("match") { |line| line.include?("/") || line.match?(/\d:/) }

            def format_write = ok(tool_use_input[:file_path])
            def format_skill = ok(tool_use_input[:skill])
            def format_taskupdate = ok(preview_line(content))
            def format_agent = ok(preview_line(agent_text(content)))

            def format_taskoutput
              fragment = Nokogiri::XML::DocumentFragment.parse(content.to_s)
              ok((fragment.at_xpath(".//status") || fragment.at_xpath(".//retrieval_status"))&.text&.strip)
            end

            def format_todowrite
              todos = tool_use_input[:todos] || []
              return ok if todos.empty?

              active = todos.find { |todo| todo[:status] == "in_progress" }
              return ok("→ #{active[:activeForm] || active[:content]}") if active

              ok("#{todos.count { |todo| todo[:status] == "completed" }}/#{todos.length} done")
            end

            def format_unknown = "UNKNOWN [#{tool_name}] OK #{tool_use_description}\n#{content}"

            # Identical twins — same body, label differs via tool_name.
            alias_method :format_edit, :format_write
            alias_method :format_taskcreate, :format_taskupdate
            alias_method :format_task, :format_agent

            # --- helpers ------------------------------------------------------------

            def label = tool_name.to_s.upcase

            # Builds "<TOOL> OK" or "<TOOL> OK <summary>"; nil/blank -> bare OK.
            def ok(summary = nil)
              summary = summary.to_s.strip
              summary.empty? ? "#{label} OK" : "#{label} OK #{summary}"
            end

            def preview_line(text) = truncate(text.to_s.lines.first.to_s.strip)

            # Glob/Grep share this: partition lines into matches vs notes, report
            # the count, and append the first note as a trailing NOTE when matches
            # were found. `found` adds glob's "found" suffix; the block is the
            # per-tool match predicate.
            def list_summary(noun, found: false, &matched)
              lines = content.to_s.lines.map(&:strip).reject(&:empty?)
              hits, notes = lines.partition(&matched)
              phrase = "#{hits.length} #{noun.pluralize(hits.length)}#{" found" if found}"
              return ok(phrase) if hits.empty? || notes.empty?

              ok("#{phrase} NOTE #{truncate(notes.join(" "))}")
            end

            def error_line
              message = content.to_s.gsub(%r{</?tool_use_error>}, "").lines.first.to_s.strip
              "#{label} ERROR #{message}"
            end

            def agent_text(value)
              return value.to_s unless value.is_a?(Array)

              value.filter_map { |block| block.is_a?(Hash) ? (block[:text] || block["text"]) : block }.join("\n")
            end

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
