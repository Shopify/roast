# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          # Formats a Pi tool execution result for progress display
          #
          # Tool results represent the output of a tool execution, which may be
          # successful content or an error.
          class ToolResult
            #: String
            attr_reader :tool_name

            #: String?
            attr_reader :content

            #: bool
            attr_reader :is_error

            #: (tool_name: String, content: String?, is_error: bool) -> void
            def initialize(tool_name:, content:, is_error:)
              @tool_name = tool_name
              @content = content
              @is_error = is_error
            end

            #: () -> String
            def format
              status = is_error ? "ERROR" : "OK"
              preview = content_preview
              "RESULT [#{tool_name}] #{status}#{preview ? ": #{preview}" : ""}"
            end

            private

            MAX_PREVIEW_LENGTH = 200 #: Integer

            #: () -> String?
            def content_preview
              return nil if content.nil? || content.empty?

              truncated = content.strip.gsub(/\s+/, " ")
              if truncated.length > MAX_PREVIEW_LENGTH
                "#{truncated[0...MAX_PREVIEW_LENGTH]}..."
              else
                truncated
              end
            end
          end
        end
      end
    end
  end
end
