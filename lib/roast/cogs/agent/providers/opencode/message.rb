# typed: false
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Opencode < Provider
          class Message
            class << self
              #: (String) -> Message
              def from_json(json)
                new(JSON.parse(json))
              end
            end

            attr_reader :type, :timestamp, :session_id, :part

            def initialize(hash)
              @type = hash.fetch("type").to_sym
              @timestamp = hash.fetch("timestamp")
              @session_id = hash.fetch("sessionID")
              @part = hash.fetch("part")
            end
          end
        end
      end
    end
  end
end
