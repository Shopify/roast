# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
end

execute do
  ruby do
    # The workflow automatically gets a temporary directory created for it
    # unique to a single execution of the workflow, but shared across all executor scopes.
    # This working directory will be cleaned up automatically when the workflow completes or fails.
    puts tmpdir

    # The value of `tmpdir` will always be a directory that exists
    raise StandardError, "temporary directory does not exist" unless tmpdir.exist?

    # The value of `tmpdir` will always be an absolute path
    raise StandardError, "temporary directory is not an absolute path" unless tmpdir.absolute?
  end
end
