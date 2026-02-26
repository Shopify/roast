# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class SystemMessage < Message
              IGNORED_FIELDS = [
                :agents,
                :apiKeySource,
                :compact_metadata,
                :claude_code_version,
                :cwd,
                :exit_code,
                :fast_mode_state,
                :hook_event,
                :hook_name,
                :mcp_servers,
                :output_style,
                :permissionMode,
                :plugins,
                :skills,
                :slash_commands,
                # TODO: "status": "compacting" indicates compaction in progress. We might want to handle that someday
                :status,
                :stderr,
                :stdout,
                :subtype,
                :tools,
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
