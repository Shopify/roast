# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolResult
            #: Symbol?
            attr_reader :tool_name

            #: String?
            attr_reader :content

            #: bool
            attr_reader :is_error

            #: (tool_call: Messages::ToolCallEndMessage?, content: String?, is_error: bool) -> void
            def initialize(tool_call:, content:, is_error:)
              @tool_name = tool_call&.name || :unknown
              @content = content
              @is_error = is_error
            end

            #: () -> String
            def format
              format_method_name = "format_#{tool_name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            private

            #: () -> String
            def format_unknown
              "UNKNOWN [#{tool_name}] #{is_error ? "ERROR" : "OK"}\n#{content}"
            end
          end
        end
      end
    end
  end
end
