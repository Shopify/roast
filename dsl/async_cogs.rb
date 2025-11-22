# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { display! }

  # Any type of cog can be configured to run asynchronously in the background.
  # The cog that follows it in the workflow will be able to begin running immediately.
  cmd(/slow/) { async! }
end

execute do
  # 'first' is synchronous; nothing else runs until it completes.
  cmd(:first) { "echo first" }

  # These cogs are async and slow, so we kick them off in the background (via the 'async!' config option)
  # Other cogs can continue while these cog runs in the background
  cmd(:slow_background_task_1) do
    sleep 0.1
    "echo slow background task 1"
  end
  cmd(:slow_background_task_2) do
    sleep 0.2
    "echo slow background task 2"
  end

  cmd(:second) { "echo second" }
  cmd(:third) { "echo third" }

  # 'fourth' accesses the output of 'slow_background_task_1'.
  # It will block until 'slow_background_task_1' completes.
  # 'fourth' is synchronous, so cogs that follow it will also be forced to wait (whether they are async or not)
  cmd(:fourth) do
    "echo \"fourth <-- '#{cmd!(:slow_background_task_1).out}'\""
  end

  cmd(:fifth) { "echo fifth" }

  # The overall completion order of these cogs is:
  # first
  # second : run right after first; does not have to wait for the slow background tasks to complete
  # third
  # slow_background_task_1
  # fourth : forced to wait for slow_background_task_1 to complete to access its input
  # fifth
  # slow_background_task_2 : the workflow will not complete until all async cogs have completed
end
