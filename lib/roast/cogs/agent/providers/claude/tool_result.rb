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
