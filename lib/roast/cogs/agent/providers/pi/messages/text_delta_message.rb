# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class TextDeltaMessage < Message
              IGNORED_FIELDS = [
                :message,
              ].freeze

              #: String
              attr_reader :delta

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                event = hash.delete(:assistantMessageEvent) || {}
                @delta = event[:delta] || ""
                event.except!(:type, :delta, :contentIndex, :partial)
                hash.merge!(event) unless event.empty?
                hash.except!(*IGNORED_FIELDS)
                super(type:, hash:)
              end

              #: (PiInvocation::Context) -> String?
              def format(context)
                @delta
              end
            end
          end
        end
      end
    end
  end
end
