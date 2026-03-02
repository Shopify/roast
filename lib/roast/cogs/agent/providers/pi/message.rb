# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          # Base message class for parsing Pi's streaming JSON output
          #
          # Pi outputs newline-delimited JSON messages with a `type` field that determines
          # the message kind. This class provides a factory for dispatching to the appropriate
          # message subclass based on the type.
          #
          # Pi message types:
          # - session: Initial session metadata (id, version, cwd)
          # - agent_start: Agent execution has begun
          # - agent_end: Agent execution is complete, contains full conversation
          # - turn_start: A new turn (request/response cycle) has started
          # - turn_end: A turn has completed, contains usage stats
          # - message_start: A message (user or assistant) is starting
          # - message_update: Streaming delta for an assistant message
          # - message_end: A message is complete
          # - tool_execution_start: A tool is being executed
          # - tool_execution_end: A tool execution has completed
          class Message
            class << self
              #: (String, ?raw_dump_file: Pathname?) -> Message?
              def from_json(json, raw_dump_file: nil)
                if raw_dump_file
                  raw_dump_file.dirname.mkpath
                  File.write(raw_dump_file.to_s, "#{json}\n", mode: "a")
                end
                from_hash(JSON.parse(json, symbolize_names: true))
              end

              #: (Hash[Symbol, untyped]) -> Message
              def from_hash(hash)
                type = hash.delete(:type)&.to_s
                case type
                when "session"
                  Messages::SessionMessage.new(type:, hash:)
                when "agent_start"
                  Messages::AgentStartMessage.new(type:, hash:)
                when "agent_end"
                  Messages::AgentEndMessage.new(type:, hash:)
                when "turn_start"
                  Messages::TurnStartMessage.new(type:, hash:)
                when "turn_end"
                  Messages::TurnEndMessage.new(type:, hash:)
                when "message_start"
                  Messages::MessageStartMessage.new(type:, hash:)
                when "message_update"
                  Messages::MessageUpdateMessage.new(type:, hash:)
                when "message_end"
                  Messages::MessageEndMessage.new(type:, hash:)
                when "tool_execution_start"
                  Messages::ToolExecutionStartMessage.new(type:, hash:)
                when "tool_execution_end"
                  Messages::ToolExecutionEndMessage.new(type:, hash:)
                else
                  Messages::UnknownMessage.new(type:, hash:)
                end
              end
            end

            #: String?
            attr_reader :type

            #: Hash[Symbol, untyped]
            attr_reader :unparsed

            #: (type: String?, hash: Hash[Symbol, untyped]) -> void
            def initialize(type:, hash:)
              @type = type
              @unparsed = hash
            end

            # Format this message for progress display
            #
            # Subclasses may override this to provide human-readable progress output.
            # Returns nil by default (no output).
            #
            #: () -> String?
            def format
              nil
            end
          end
        end
      end
    end
  end
end
