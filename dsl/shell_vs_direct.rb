# typed: true
# frozen_string_literal: true

# Demonstrates when to use shell commands (string) vs direct execution (array)
# Run with: bin/roast execute dsl/shell_vs_direct.rb

#: self as Roast::DSL::Workflow

config do
  cmd { print_all! }
end

execute do
  # ===== USE SHELL (string) when you need: =====

  # 1. Pipes
  cmd(:with_pipe) { "echo 'foo\nbar\nbaz' | grep bar" }

  # 2. Redirects
  cmd(:with_redirect) { "ls lib > /tmp/files.txt 2>&1" }

  # 3. Command substitution
  cmd(:with_subshell) { "echo Current dir: $(basename $(pwd))" }

  # 4. Wildcards/globbing
  cmd(:with_glob) { "echo *.rb" }

  # ===== USE DIRECT (array) when you need: =====

  # 1. Safety with untrusted input
  untrusted = "user; rm -rf /" # Safe because it's just an argument
  cmd(:safe_input) { ["echo", untrusted] }

  # 2. Literal special characters
  cmd(:literal_special) { ["echo", "This | is & literal; text"] }

  # 3. Exact arguments (no shell parsing)
  cmd(:exact_args) { ["git", "log", "--format=%H %s"] }

  # 4. Performance (skip shell overhead)
  cmd(:fast_exec) { ["pwd"] }

  # ===== COMBINED: Use both as needed =====

  # Shell for complex operations
  cmd(:count_files) { "find lib -name '*.rb' | wc -l" }

  # Then use result safely with array
  # (In real workflow, you'd pass the count between steps)
  cmd(:safe_report) { ["echo", "File count:", "42"] }
end
