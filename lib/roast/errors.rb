# typed: true
# frozen_string_literal: true

module Roast
  module Errors
    # Custom error for API resource not found (404) responses
    class ResourceNotFoundError < Roast::Error; end

    # Custom error for when API authentication fails
    class AuthenticationError < Roast::Error; end

    # Exit the app, for instance via Ctrl-C during an InputStep
    class ExitEarly < Roast::Error; end
  end
end
