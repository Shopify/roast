# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class TextEndMessage < Message
              IGNORED_FIELDS = [
                :message,
              ].freeze

              #: String
              attr_reader :content

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                event = hash.delete(:assistantMessageEvent) || {}
                @content = event[:content] || ""
                event.except!(:type, :content, :contentIndex, :partial)
                hash.merge!(event) unless event.empty?
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
