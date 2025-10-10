# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      # Generic output from running a cog.
      # Cogs should extend this class with their own output types.
      class Output
        #: bool
        attr_reader :success

        #: bool
        attr_reader :abort

        #: (?success: bool, ?abort: bool) -> void
        def initialize(success: true, abort: false)
          @success = success #: bool
          @abort = abort #: bool
        end
      end
    end
  end
end
