# typed: false
# frozen_string_literal: true

config do
  cmd { print_all! }
end

execute do
  # This should work perfectly and not show any error messages
  cmd(:hello) { "echo Hello World" }

  cmd(:goodbye) { "echo Goodbye" }
end
