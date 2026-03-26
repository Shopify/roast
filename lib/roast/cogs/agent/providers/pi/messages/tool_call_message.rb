# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Represents a tool call made by the Pi agent
            #
            # In Pi's JSON protocol, tool calls appear as `toolcall_end` events within
            # `message_update` messages, containing the tool name, id, and arguments.
            class ToolCallMessage
              #: String?
              attr_reader :id

              #: String?
              attr_reader :name

              #: Hash[Symbol, untyped]
              attr_reader :arguments

              #: (id: String?, name: String?, arguments: Hash[Symbol, untyped]) -> void
              def initialize(id:, name:, arguments:)
                @id = id
                @name = name
                @arguments = arguments
              end

              #: () -> String?
              def format
                return unless name

                case name.to_s.downcase
                when "bash"
                  "BASH #{arguments[:command]}"
                when "read"
                  "READ #{arguments[:path]}"
                when "edit"
                  "EDIT #{arguments[:path]}"
                when "write"
                  "WRITE #{arguments[:path]}"
                when "grep"
                  "GREP #{arguments[:pattern]} #{arguments[:path]}"
                when "find"
                  "FIND #{arguments[:pattern]} #{arguments[:path]}"
                when "ls"
                  "LS #{arguments[:path]}"
                else
                  "TOOL [#{name}] #{arguments.inspect}"
                end
              end
            end
          end
        end
      end
    end
  end
end
