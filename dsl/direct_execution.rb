# typed: true
# frozen_string_literal: true

# Demonstrates direct execution (array syntax) without shell features
# This is safer for untrusted input as it avoids shell injection
# Run with: bin/roast execute dsl/direct_execution.rb

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
end

execute do
  # Direct execution - no shell interpretation
  cmd(:safe_echo) { ["echo", "hello", "world"] }

  # Git commands with args - safe from injection
  cmd(:git_status) { ["git", "status", "--porcelain"] }

  # Find with arguments
  cmd(:find_ruby) { ["find", "lib", "-name", "*.rb", "-type", "f"] }

  # Command with special characters (treated as literals, not shell syntax)
  cmd(:literal_chars) { ["echo", "This; has & special | chars"] }

  # Demonstrate safety: this would be dangerous as a string but safe as array
  # If this were: "echo #{user_input}", injection could happen
  # As array: ["echo", user_input], it's always safe
  dangerous_input = "; rm -rf /" # Would be dangerous in shell
  cmd(:safe_from_injection) { ["echo", dangerous_input] }
end
