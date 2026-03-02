# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolCallStartMessage < Message
              IGNORED_FIELDS = [
                :message,
              ].freeze

              #: String?
              attr_reader :tool_call_id

              #: Symbol
              attr_reader :name

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                event = hash.delete(:assistantMessageEvent) || {}
                tool_call = extract_tool_call(event)
                @tool_call_id = tool_call[:id]
                @name = tool_call[:name]&.downcase&.to_sym || :unknown
                event.except!(:type, :contentIndex, :partial)
                hash.merge!(event) unless event.empty?
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              private

              #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
              def extract_tool_call(event)
                # The tool call info is in the partial's content array
                content = event.dig(:partial, :content) || []
                content.find { |c| c[:type] == "toolCall" } || {}
              end
            end
          end
        end
      end
    end
  end
end
