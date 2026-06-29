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
              end

              TRUNCATE_LIMIT = 45

              private

              #: () -> String
              def format_bash
                lines = content.to_s.lines
                count = lines.length
                ok_line("#{count} #{"line".pluralize(count)}")
              end

              #: () -> String
              def format_read
                count = content.to_s.lines.length
                ok_line("#{count} #{"line".pluralize(count)}")
              end

              #: () -> String
              def format_write
                ok_line(@input[:path])
              end

              #: () -> String
              def format_edit
                ok_line(@input[:path])
              end

              #: () -> String
              def format_unknown
                preview = truncate(content.to_s.lines.first.to_s.strip)
                ok_line(preview)
              end

              #: (*String?) -> String
              def ok_line(*parts)
                summary = parts.select(&:present?).join(" · ")
                prefix = "#{@name.upcase} OK"
                summary.present? ? "#{prefix} #{summary}" : prefix
              end

              #: () -> String
              def error_line
                "#{@name.upcase} ERROR #{content.to_s.strip}".strip
              end

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
