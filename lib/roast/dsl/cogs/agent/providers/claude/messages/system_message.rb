# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
            module Messages
              class SystemMessage < Message
                IGNORED_FIELDS = [
                  :subtype,
                  :cwd,
                  :tools,
                  :mcp_servers,
                  :permissionMode,
                  :slash_commands,
                  :apiKeySource,
                  :claude_code_version,
                  :output_style,
                  :agents,
                  :skills,
                  :plugins,
                ].freeze

                #: String?
                attr_reader :message

                #: String?
                attr_reader :model

                #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
                def initialize(type:, hash:)
                  @message = hash.delete(:message)
                  @model = hash.delete(:model)
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
