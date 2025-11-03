# typed: true
# frozen_string_literal: true

# Demonstrates working_directory with both shell and direct execution
# Run with: bin/roast execute dsl/working_directory_with_both.rb

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
  cmd(:in_tmp) { working_directory "/tmp" }
  cmd(:in_root) { working_directory "/" }
end

execute do
  # Default working directory (current dir)
  cmd(:current) { "echo Current: `pwd`" }

  # Shell commands in different directories
  cmd(:in_tmp) { "echo In tmp: $(pwd) && ls -la | head -5" }
  cmd(:in_root) { "echo In root: $(pwd) && ls -d */ | head -3" }

  # Direct execution also respects working_directory
  cmd(:in_tmp_direct) { ["pwd"] }
  cmd(:in_root_direct) { ["ls", "-d", "*/"] }

  # Back to current
  cmd(:current_again) { ["pwd"] }

  # Demonstrate: working_directory is per-command, not global
  cmd(:still_current) { "echo Still in: $(pwd)" }
end
