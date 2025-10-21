# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Generic output from running a cog.
      # Cogs should extend this class with their own output types.
      class Output; end
    end
  end
end
