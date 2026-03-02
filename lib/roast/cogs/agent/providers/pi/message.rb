# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class Message
            class << self
              #: (String, ?raw_dump_file: Pathname?) -> Message
              def from_json(json, raw_dump_file: nil)
                raw_dump_file&.dirname&.mkpath
                File.write("./tmp/pi-messages.log", "#{json}\n", mode: "a") if raw_dump_file
                from_hash(JSON.parse(json, symbolize_names: true))
              end

              #: (Hash[Symbol, untyped]) -> Message
              def from_hash(hash)
                type = hash.delete(:type)&.to_s
                case type
                when "session"
                  Messages::SessionMessage.new(type: :session, hash: hash)
                when "agent_start"
                  Messages::AgentStartMessage.new(type: :agent_start, hash: hash)
                when "agent_end"
                  Messages::AgentEndMessage.new(type: :agent_end, hash: hash)
                when "turn_start"
                  Messages::TurnStartMessage.new(type: :turn_start, hash: hash)
                when "turn_end"
                  Messages::TurnEndMessage.new(type: :turn_end, hash: hash)
                when "message_start"
                  Messages::MessageStartMessage.new(type: :message_start, hash: hash)
                when "message_end"
                  Messages::MessageEndMessage.new(type: :message_end, hash: hash)
                when "message_update"
                  from_message_update(hash)
                when "tool_execution_start"
                  Messages::ToolExecutionStartMessage.new(type: :tool_execution_start, hash: hash)
                when "tool_execution_update"
                  Messages::ToolExecutionUpdateMessage.new(type: :tool_execution_update, hash: hash)
                when "tool_execution_end"
                  Messages::ToolExecutionEndMessage.new(type: :tool_execution_end, hash: hash)
                else
                  Messages::UnknownMessage.new(type: type&.to_sym || :unknown, hash: hash)
                end
              end

              private

              #: (Hash[Symbol, untyped]) -> Message
              def from_message_update(hash)
                event = hash[:assistantMessageEvent]
                sub_type = event&.dig(:type)&.to_s

                case sub_type
                when "text_start"
                  Messages::TextStartMessage.new(type: :text_start, hash: hash)
                when "text_delta"
                  Messages::TextDeltaMessage.new(type: :text_delta, hash: hash)
                when "text_end"
                  Messages::TextEndMessage.new(type: :text_end, hash: hash)
                when "thinking_start"
                  Messages::ThinkingStartMessage.new(type: :thinking_start, hash: hash)
                when "thinking_delta"
                  Messages::ThinkingDeltaMessage.new(type: :thinking_delta, hash: hash)
                when "thinking_end"
                  Messages::ThinkingEndMessage.new(type: :thinking_end, hash: hash)
                when "toolcall_start"
                  Messages::ToolCallStartMessage.new(type: :toolcall_start, hash: hash)
                when "toolcall_delta"
                  Messages::ToolCallDeltaMessage.new(type: :toolcall_delta, hash: hash)
                when "toolcall_end"
                  Messages::ToolCallEndMessage.new(type: :toolcall_end, hash: hash)
                else
                  Messages::UnknownMessage.new(type: :unknown, hash: hash)
                end
              end
            end

            #: Symbol
            attr_reader :type

            #: Hash[Symbol, untyped]
            attr_reader :unparsed

            #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
            def initialize(type:, hash:)
              @type = type
              @unparsed = hash
            end

            #: (PiInvocation::Context) -> String?
            def format(context)
            end
          end
        end
      end
    end
  end
end
