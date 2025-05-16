# frozen_string_literal: true

module Roast
  # Custom error for API resource not found (404) responses
  class ResourceNotFoundError < StandardError; end

  # Custom error for when API authentication fails
  class AuthenticationError < StandardError; end
end
