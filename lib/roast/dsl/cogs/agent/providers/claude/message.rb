# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            class Message
              IGNORED_FIELDS = [
                :uuid,
              ].freeze

              class << self
                #: (String) -> Message
                def from_json(json)
                  from_hash(JSON.parse(json, symbolize_names: true))
                end

                #: (Hash[Symbol, untyped]) -> Message
                def from_hash(hash)
                  type = hash.delete(:type)&.to_sym
                  case type
                  when :assistant
                    Messages::AssistantMessage.new(type:, hash:)
                  when :result
                    Messages::ResultMessage.new(type:, hash:)
                  when :system
                    Messages::SystemMessage.new(type:, hash:)
                  when :text
                    Messages::TextMessage.new(type:, hash:)
                  else
                    Messages::UnknownMessage.new(type:, hash:)
                  end
                end
              end

              #: String?
              attr_reader :session_id

              #: Symbol
              attr_reader :type

              #: Hash[Symbol, untyped]
              attr_reader :unparsed

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @session_id = hash.delete(:session_id)
                @type = type
                hash.except!(*IGNORED_FIELDS)
                @unparsed = hash
              end

              #: () -> String?
              def format
              end
            end
          end
        end
      end
    end
  end
end
