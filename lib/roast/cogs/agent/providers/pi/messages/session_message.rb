# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Parses the initial session message from Pi
            #
            # Example:
            #   {"type":"session","version":3,"id":"abc-123","timestamp":"...","cwd":"/path"}
            class SessionMessage < Message
              #: String?
              attr_reader :session_id

              #: Integer?
              attr_reader :version

              #: String?
              attr_reader :cwd

              #: String?
              attr_reader :timestamp

              #: (type: String?, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                @session_id = hash.delete(:id)
                @version = hash.delete(:version)
                @cwd = hash.delete(:cwd)
                @timestamp = hash.delete(:timestamp)
                super(type:, hash:)
              end
            end
          end
        end
      end
    end
  end
end
