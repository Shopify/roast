# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Chat < Cog
        # Container for chat session information needed to resume a conversation
        #
        # Holds the messages from a chat conversation and provides methods to
        # truncate or restore the session.
        class Session
          class << self
            # Create a new session from a RubyLLM chat instance
            #
            #: (RubyLLM::Chat) -> Session
            def from_chat(chat)
              messages = chat.messages.deep_dup
              Session.new(messages)
            end
          end

          # Initialize a new session with the given messages
          #
          #: (Array[RubyLLM::Message]) -> void
          def initialize(messages)
            @messages = messages
          end

          # Get a truncated session consisting only of the first N messages
          #
          # Each full turn in a conversation consists of two messages (a prompt and a response),
          # so to include N full turns you should pass `2 * N` as the argument.
          # The default value is `2`, which returns only the first full turn.
          #
          #: (?Integer) -> Session
          def first(n = 2)
            messages = @messages.first(n).deep_dup
            Session.new(messages)
          end

          # Get a truncated session consisting only of the last N messages
          #
          # Each full turn in a conversation consists of two messages (a prompt and a response),
          # so to include N full turns you should pass `2 * N` as the argument.
          # The default value is `2`, which returns only the last full turn.
          #
          #: (?Integer) -> Session
          def last(n = 2)
            messages = @messages.last(n).deep_dup
            Session.new(messages)
          end

          # Apply this session's messages to a RubyLLM chat instance
          #
          # Replaces the chat's messages with this session's messages, effectively
          # restoring the conversation state.
          #
          #: (RubyLLM::Chat) -> void
          def apply!(chat)
            chat.instance_variable_set(:@messages, @messages.deep_dup)
            chat.with_temperature(@temperature) if @temperature
          end
        end
      end
    end
  end
end
