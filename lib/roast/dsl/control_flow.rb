# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Errors that can be raised to control workflow execution
    module ControlFlow
      # Raised in a cog's input block or execute method to terminate the cog and mark it as 'skipped'
      # without triggering any failure handling
      class SkipCog < StandardError; end

      # Raised in a cog's input block or execute method to terminate the cog and mark it as 'failed'
      # without terminating the workflow
      class FailCog < StandardError; end

      # Raised in a cog's input block within a repeat loop to break out of the loop
      class BreakLoop < StandardError; end
    end
  end
end
