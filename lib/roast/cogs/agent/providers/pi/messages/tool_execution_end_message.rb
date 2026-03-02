# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolExecutionEndMessage < Message
              #: String?
              attr_reader :tool_call_id

              #: String?
              attr_reader :tool_name

              #: Hash[Symbol, untyped]?
              attr_reader :result_data

              #: bool
              attr_reader :is_error

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @tool_call_id = hash.delete(:toolCallId)
                @tool_name = hash.delete(:toolName)
                @result_data = hash.delete(:result)
                @is_error = hash.delete(:isError) || false
                super(type:, hash:)
              end

              #: (PiInvocation::Context) -> String?
              def format(context)
                tool_call = context.tool_call(tool_call_id)
                content = extract_content
                tool_result = ToolResult.new(tool_call:, content:, is_error:)
                tool_result.format
              end

              private

              #: () -> String?
              def extract_content
                return unless result_data

                content_items = result_data&.dig(:content)
                return result_data.to_s unless content_items.is_a?(Array)

                content_items
                  .select { |c| c[:type] == "text" }
                  .map { |c| c[:text] }
                  .join
              end
            end
          end
        end
      end
    end
  end
end
