# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Chat < Cog
      class SessionTest < ActiveSupport::TestCase
        def setup
          configure_ruby_llm

          @messages = [
            RubyLLM::Message.new(role: "user", content: "Hello"),
            RubyLLM::Message.new(role: "assistant", content: "Hi there!"),
            RubyLLM::Message.new(role: "user", content: "How are you?"),
            RubyLLM::Message.new(role: "assistant", content: "I'm doing well!"),
          ]
          @session = Session.new(@messages)
        end

        test "initialize stores messages" do
          assert_nothing_raised do
            Session.new(@messages)
          end
        end

        test "first returns session with first N messages" do
          truncated = @session.first(3)

          chat = create_chat
          truncated.apply!(chat)

          assert_equal 3, chat.messages.size
          assert_equal "Hello", chat.messages[0].content
          assert_equal "Hi there!", chat.messages[1].content
          assert_equal "How are you?", chat.messages[2].content
        end

        test "first defaults to 2 messages" do
          truncated = @session.first

          chat = create_chat
          truncated.apply!(chat)

          assert_equal 2, chat.messages.size
        end

        test "first deep duplicates messages" do
          truncated = @session.first(2)

          chat = create_chat
          truncated.apply!(chat)

          # Modify original messages
          @messages[0].content = "Modified"

          # Truncated session should be unaffected
          refute_equal "Modified", chat.messages[0].content
        end

        test "last returns session with last N messages" do
          truncated = @session.last(2)

          chat = create_chat
          truncated.apply!(chat)

          assert_equal 2, chat.messages.size
          assert_equal "How are you?", chat.messages[0].content
          assert_equal "I'm doing well!", chat.messages[1].content
        end

        test "last defaults to 2 messages" do
          truncated = @session.last

          chat = create_chat
          truncated.apply!(chat)

          assert_equal 2, chat.messages.size
        end

        test "last deep duplicates messages" do
          truncated = @session.last(2)

          chat = create_chat
          truncated.apply!(chat)

          # Modify original messages
          @messages[3].content = "Modified"

          # Truncated session should be unaffected
          refute_equal "Modified", chat.messages[1].content
        end

        test "apply! sets messages on chat instance" do
          chat = create_chat
          chat.add_message(role: "user", content: "Old")

          @session.apply!(chat)

          assert_equal 4, chat.messages.size
          assert_equal "Hello", chat.messages[0].content
        end

        test "apply! deep duplicates messages to chat" do
          chat = create_chat
          @session.apply!(chat)

          # Modify original messages
          @messages[0].content = "Modified"

          # Chat should be unaffected
          refute_equal "Modified", chat.messages[0].content
        end

        test "from_chat creates session from RubyLLM::Chat instance" do
          chat = create_chat_with_messages

          session = Session.from_chat(chat)

          # Apply to another chat to verify
          another_chat = create_chat
          session.apply!(another_chat)

          assert_equal 4, another_chat.messages.size
        end

        test "from_chat deep duplicates messages from chat" do
          chat = create_chat_with_messages

          session = Session.from_chat(chat)

          # Modify the chat's messages
          chat.messages[0].content = "Modified"

          # Session should be unaffected
          another_chat = create_chat
          session.apply!(another_chat)
          refute_equal "Modified", another_chat.messages[0].content
        end

        private

        def configure_ruby_llm
          RubyLLM.configure do |config|
            config.openai_api_key = "test-key"
          end
        end

        def create_chat
          RubyLLM::Chat.new(provider: :openai, assume_model_exists: true)
        end

        def create_chat_with_messages
          chat = create_chat
          chat.add_message(role: "user", content: "Hello")
          chat.add_message(role: "assistant", content: "Hi there!")
          chat.add_message(role: "user", content: "How are you?")
          chat.add_message(role: "assistant", content: "I'm doing well!")
          chat
        end
      end
    end
  end
end
