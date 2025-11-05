# typed: false
# frozen_string_literal: true

execute do
  # This should trigger input validation error - Chat cog requires 'prompt'
  chat(:test_chat)
end
