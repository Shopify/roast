# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Claude < Provider
          module Messages
            class ResultMessage < Message
              IGNORED_FIELDS = [
                :duration_api_ms,
                :permission_denials,
                :usage,
                :uuid,
              ].freeze

              #: String
              attr_reader :content

              #: bool
              attr_reader :success

              #: Stats
              attr_reader :stats

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                subtype = hash.delete(:subtype)
                @content = hash.delete(:result) || ""
                @success = hash.delete(:success) || subtype == "success"
                if hash.delete(:is_error) || subtype == "error"
                  @content = @content || hash.dig(:error, :message) || "Unknown error"
                  hash.delete(:error)
                end

                @stats = Stats.new
                @stats.duration_ms = hash.delete(:duration_ms)
                @stats.num_turns = hash.delete(:num_turns)
                hash.delete(:modelUsage)&.each do |model, h|
                  usage = Usage.new
                  usage.input_tokens = h[:inputTokens]
                  usage.output_tokens = h[:outputTokens]
                  usage.cost_usd = h[:costUSD]
                  @stats.model_usage[model] = usage
                  @stats.usage.input_tokens = (@stats.usage.input_tokens || 0) + (usage.input_tokens || 0)
                  @stats.usage.output_tokens = (@stats.usage.output_tokens || 0) + (usage.output_tokens || 0)
                end
                @stats.usage.cost_usd = hash.delete(:total_cost_usd)
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
