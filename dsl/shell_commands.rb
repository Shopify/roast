# typed: true
# frozen_string_literal: true

# Demonstrates shell command support with pipes, redirects, and command substitution
# Run with: bin/roast execute dsl/shell_commands.rb

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
end

execute do
  # Shell pipeline - count dirty files
  cmd(:count_dirty_files) { "git status --porcelain | wc -l | tr -d '\n'" }

  # Multiple pipes and grep
  cmd(:find_ruby_files) { "find . -name '*.rb' | grep -v test | head -5" }

  # Command substitution
  cmd(:current_branch) { "echo Current branch: $(git branch --show-current)" }

  # Variable expansion
  cmd(:with_vars) { "VAR='Hello World' && echo $VAR" }

  # Output redirection (creates temp file)
  cmd(:with_redirect) { "echo 'test content' > /tmp/roast_test.txt && cat /tmp/roast_test.txt" }

  # Complex shell features
  cmd(:for_loop) { "for i in 1 2 3; do echo \"Number: $i\"; done | grep '2'" }
end
