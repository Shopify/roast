# typed: false
# frozen_string_literal: true

config do
  # This should trigger InvalidConfigError - nonexistent working directory
  cmd(:test_cmd) { working_directory("/nonexistent/directory/that/should/not/exist") }
end

execute do
  cmd(:test_cmd) { "echo hello" }
end
