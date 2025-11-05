# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            module Messages
              class ToolUseMessage < Message
                IGNORED_FIELDS = [
                  :id,
                  :role,
                ].freeze

                #: Symbol
                attr_reader :name

                #: Hash[Symbol, untyped]
                attr_reader :input

                #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
                def initialize(type:, hash:)
                  @id = hash.delete(:id) || ""
                  @name = hash.delete(:name)&.to_sym || :unknown
                  @input = hash.delete(:input) || {}
                  hash.except!(*IGNORED_FIELDS)
                  super(type:, hash:)
                end

                #: () -> String
                def format
                  tool_use = ToolUse.new(name:, input:)
                  tool_use.format
                end
              end
            end
          end
        end
      end
    end
  end
end
