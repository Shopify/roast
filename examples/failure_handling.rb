# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# Two independent switches decide what a failing cog does to the workflow around it:
# whether a non-zero exit status counts as a failure at all (`fail_on_error!`, `cmd` only),
# and whether a failed cog stops the workflow (`abort_on_failure!`, any cog). A cog can
# also fail itself with `fail!`. Both switches default to the strict setting, which is why
# this workflow ends by aborting: run it with `roast execute examples/failure_handling.rb`
# and the abort at the end is the last thing it demonstrates, not a broken example.

config do
  cmd { display! }

  # A non-zero exit status from this cog is not a failure: the cog succeeds, and the
  # exit status is left on its output for another cog to read.
  cmd(:count_gammas) { no_fail_on_error! }

  # This cog is allowed to fail without stopping the workflow. It is still failed:
  # it produces no output, so no other cog can read anything from it.
  cmd(:fetch_optional) { no_abort_on_failure! }

  # `continue_on_failure!` is an alias of `no_abort_on_failure!`, and both work on any cog.
  ruby(:check_optional) { continue_on_failure! }
end

execute do
  # `grep -c` exits 1 when it counts nothing, which is not a failure worth aborting for.
  cmd(:count_gammas) { "printf 'alpha\\nbeta\\n' | grep -c gamma" }

  ruby do
    # The cog succeeded, so `cmd!` returns its output and the exit status is there to read.
    output = cmd!(:count_gammas)
    puts "count_gammas printed #{output.out.strip.inspect} and exited #{output.status.exitstatus}"
  end

  # This command's non-zero exit status does mark the cog failed, and the workflow runs
  # the next cog anyway, because the cog is configured not to abort on failure.
  # Note that what the command printed before it failed is in the log but nowhere else:
  # a failed cog has no output object, so no other cog can read it back.
  cmd(:fetch_optional) { "echo no optional source configured; exit 7" }

  ruby(:check_optional) do
    # Use `fail!` in a cog's input block to mark the cog failed yourself, which is how a
    # cog declares that its own precondition is missing. The input block terminates
    # immediately. The message is for whoever is reading the workflow: Roast does not
    # surface it anywhere yet.
    fail!("nothing to check") unless cmd?(:fetch_optional)
  end

  ruby(:summary) do
    # The three output accessors each answer a different question about a failed cog.
    puts "cmd?(:fetch_optional) -> #{cmd?(:fetch_optional)}"
    puts "cmd(:fetch_optional) -> #{cmd(:fetch_optional).inspect}"
    begin
      cmd!(:fetch_optional)
    rescue Roast::CogInputManager::CogFailedError => e
      puts "cmd!(:fetch_optional) raised #{e.class}"
    end
    # A cog that failed by calling `fail!` is no different to read from.
    puts "ruby?(:check_optional) -> #{ruby?(:check_optional)}"
  end

  # Left at the defaults: this cog fails, and a failed cog aborts the workflow.
  cmd(:required) do
    puts "❗️ This cog is expected to abort the workflow ❗️"
    "exit 1"
  end

  # Nothing after an aborting cog runs, so this cog never starts.
  ruby { puts "this line is never printed" }
end
