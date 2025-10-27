# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }

  # Any type of cog can be configured to run asynchronously.
  # The cog that follows it in the workflow will be able to begin running immediately, before the async cog has finished.
  cmd(:second) { async! }

  # If there are a mix of sync and async cogs in a workflow, any synchronous cog may begin running before any
  # async cogs above it have completed, but no cogs below it -- sync or async -- will start until it has completed.
  cmd(:third) { no_async! } # NOTE: `no_async!` is redundant here (it's the default); but included here for extra clarity.
  cmd(:fourth) { async! }
  cmd(:fifth) { async! }
  cmd(:sixth) { async! }
end

execute do
  # 'first' is synchronous; nothing else runs until it completes.
  cmd(:first) { "echo first" }

  # 'second' is async and slow; it will not complete until after 'third' is done,
  # but 'third' will be allowed to start right away.
  cmd(:second) do
    sleep 0.2
    "echo second"
  end

  # 'third is synchronous and medium-speed; it will not wait for the async cogs above it,
  # so it will complete before the slow, async 'second' cog.
  cmd(:third) do
    sleep 0.1
    "echo third"
  end

  # 'fourth' is async, but it will not be allowed to start until the synchronous 'third' cog about it has completed.
  # It will still complete before the slow-running 'second' cog, though.
  cmd(:fourth) { "echo fourth" }

  # 'fifth' is async, and fast, and will start before the slow-running 'second' cog.
  # However, its input depends on the output of 'second', so it will automatically wait for 'second' to complete.
  cmd(:fifth) do
    # All the output accessors -- cmd?(:name), cmd(:name), cmd!(:name) -- will block
    # until the named async cog is complete IF AND ONLY IF it has already started.
    # If the named cog is defined later in the workflow and thus not already started,
    # these methods will return immediately.
    "echo \"fifth (second said: '#{cmd!(:second).out}')\""
  end

  # 'sixth' is async as well, and it will complete before the slow-running 'second' cog AND before the 'fifth' cog
  # that is blocking on the output of 'second'
  cmd(:sixth) do
    sleep 0.01 # just to make sure this runs slightly slower than 'fourth' to maintain deterministic ordering
    "echo sixth"
  end

  # The overall completion order of these cogs is:
  # first : synchronous; nothing else started until it was done
  # third : synchronous; did not block on the async 'second' cog
  # fourth : async; could not start until after 'third'
  # sixth : async; started at the same time as 'fourth', ran very slightly slower
  # second : async, slow; started right after 'first', but didn't complete until now
  # fifth : async; faster than 'second' but depended on its output, so it blocked until 'second' was complete
end
