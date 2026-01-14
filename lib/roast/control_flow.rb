# typed: true
# frozen_string_literal: true

module Roast
  # Errors that can be raised to control workflow execution
  module ControlFlow
    class Base < StandardError; end

    # Raised in a cog's input block or execute method to terminate the cog and mark it as 'skipped'
    # without triggering any failure handling
    class SkipCog < Base; end

    # Raised in a cog's input block or execute method to terminate the cog and mark it as 'failed'
    # without terminating the workflow. The workflow may abort anyway if the cog is configured to abort the
    # workflow on failure.
    class FailCog < Base; end

    # Raised in a cog's input block or execute method to terminate the current loop iteration
    # and start the next iteration immediately. The current cog will be marked as 'skipped',
    # and every subsequent cog in the current iteration will not run. Any async cogs currently running in the
    # current scope will be stopped.
    #
    # If this exception is raised outside of a loop (e.g, via the `call` cog, or in the top-level executor),
    # this exception will just terminate that executor as described above without starting a 'next' iteration.
    class Next < Base; end

    # Raised in a cog's input block or execute method to terminate the current loop iteration immediately
    # and skip all subsequent loop iterations. The current cog will be marked as 'skipped',
    # and every subsequent cog in the current iteration will not run. Any async cogs currently running in the
    # current scope will be stopped.
    #
    # If this exception is raised outside of a loop (e.g, via the `call` cog, or in the top-level executor),
    # this exception will just terminate that executor as described above without starting a 'next' iteration.
    #
    # If this exception is raised inside a `map`, this exception will prevent any subsequent executor invocations
    # within that map and will stop any async invocations running in parallel.
    class Break < Base; end
  end
end
