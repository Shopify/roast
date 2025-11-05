# typed: false
# frozen_string_literal: true

execute do
  # This should trigger NoMethodError - using a method that doesn't exist
  cmd(:test) { "echo hello" }

  undefined_cog_method(:test)
end
