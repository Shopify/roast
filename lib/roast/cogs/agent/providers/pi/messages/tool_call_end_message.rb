# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class ToolCallEndMessage < Message
              IGNORED_FIELDS = [
                :message,
              ].freeze

              #: String?
              attr_reader :tool_call_id

              #: Symbol
              attr_reader :name

              #: Hash[Symbol, untyped]
              attr_reader :arguments

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                event = hash.delete(:assistantMessageEvent) || {}
                tool_call = event[:toolCall] || {}
                @tool_call_id = tool_call[:id]
                @name = tool_call[:name]&.downcase&.to_sym || :unknown
                @arguments = tool_call[:arguments] || {}
                event.except!(:type, :toolCall, :contentIndex, :partial)
                hash.merge!(event) unless event.empty?
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              #: (PiInvocation::Context) -> String?
              def format(context)
                tool_use = ToolUse.new(name:, input: arguments)
                tool_use.format
              end
            end
          end
        end
      end
    end
  end
end
