# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ToolResultMessage < Message
              IGNORED_FIELDS = [
                :role,
              ].freeze

              #: String?
              attr_reader :tool_use_id

              #: String?
              attr_reader :content

              #: bool
              attr_reader :is_error

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @tool_use_id = hash.delete(:tool_use_id)
                @content = hash.delete(:content)
                @is_error = hash.delete(:is_error) || false
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              #: (ClaudeInvocation::Context) -> String?
              def format(context)
                tool_use = context.tool_use(tool_use_id)
                tool_result = ToolResult.new(tool_use:, content:, is_error:)
                tool_result.format
              end
            end
          end
        end
      end
    end
  end
end
