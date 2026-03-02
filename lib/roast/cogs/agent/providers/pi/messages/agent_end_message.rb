# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Final message emitted by Pi containing the full conversation history
            #
            # Extracts the final response text and computes aggregate usage statistics
            # from all assistant messages in the conversation.
            class AgentEndMessage < Message
              #: String
              attr_reader :response

              #: bool
              attr_reader :success

              #: Stats
              attr_reader :stats

              #: (type: Symbol, hash: Hash[Symbol, untyped]) -> void
              def initialize(type:, hash:)
                messages = hash.delete(:messages) || []
                @response = extract_response(messages)
                @success = true
                @stats = extract_stats(messages)
                super(type:, hash:)
              end

              private

              # Extract the final text response from the last assistant message
              #
              #: (Array[Hash[Symbol, untyped]]) -> String
              def extract_response(messages)
                last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
                return "" unless last_assistant

                content = last_assistant[:content] || []
                content
                  .select { |c| c[:type] == "text" }
                  .map { |c| c[:text] }
                  .join
                  .strip
              end

              # Compute aggregate stats from all assistant messages
              #
              #: (Array[Hash[Symbol, untyped]]) -> Stats
              def extract_stats(messages)
                stats = Stats.new
                assistant_messages = messages.select { |m| m[:role] == "assistant" }

                assistant_messages.each do |msg|
                  usage_data = msg[:usage]
                  next unless usage_data

                  model = msg[:model] || "unknown"
                  model_usage = stats.model_usage[model] ||= Usage.new

                  input = usage_data[:input] || 0
                  output = usage_data[:output] || 0
                  cost = usage_data.dig(:cost, :total) || 0.0

                  model_usage.input_tokens = (model_usage.input_tokens || 0) + input
                  model_usage.output_tokens = (model_usage.output_tokens || 0) + output
                  model_usage.cost_usd = (model_usage.cost_usd || 0.0) + cost

                  stats.usage.input_tokens = (stats.usage.input_tokens || 0) + input
                  stats.usage.output_tokens = (stats.usage.output_tokens || 0) + output
                  stats.usage.cost_usd = (stats.usage.cost_usd || 0.0) + cost
                end

                stats
              end
            end
          end
        end
      end
    end
  end
end
