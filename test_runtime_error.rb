# typed: false
# frozen_string_literal: true

config do
  cmd { print_all! }
end

execute do
  # This should trigger a generic runtime error (command not found)
  cmd(:bad_command) { "nonexistent_command_that_should_fail_completely" }
end
