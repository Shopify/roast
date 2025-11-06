# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            class ToolResult
              #: Symbol?
              attr_reader :tool_name

              #: String?
              attr_reader :tool_use_description

              #: String?
              attr_reader :content

              #: bool
              attr_reader :is_error

              #: (tool_use: Messages::ToolUseMessage?, content: String?, is_error: bool) -> void
              def initialize(tool_use:, content:, is_error:)
                @tool_name = tool_use&.name || :unknown
                @tool_use_description = tool_use&.input&.fetch(:description, nil) #: String?
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
                ::CLI::UI.fmt(" {{red:⏺}} TOOL RESULT [#{tool_name}] #{is_error ? " ERROR" : "OK"} #{tool_use_description || ""}\n#{content}")
              end
            end
          end
        end
      end
    end
  end
end
