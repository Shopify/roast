# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            class SessionMessage < Message
              IGNORED_FIELDS = [
                :version,
                :timestamp,
                :cwd,
              ].freeze

              #: String?
              attr_reader :session_id

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @session_id = hash.delete(:id)
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
