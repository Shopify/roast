# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            module Messages
              class UserMessage < Message
                IGNORED_FIELDS = [
                  :parent_tool_use_id,
                ].freeze

                #: Array[Message]
                attr_reader :messages

                #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
                def initialize(type:, hash:)
                  @messages = hash.dig(:message, :content)&.map do |content|
                    content[:role] = :user
                    Message.from_hash(content)
                  end&.compact || []
                  hash.delete(:message)
                  hash.except!(*IGNORED_FIELDS)
                  super(type:, hash:)
                end
              end
            end
          end
        end
      end
    end
  end
end
