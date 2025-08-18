# typed: true
# frozen_string_literal: true
#: self as Roast::DSL::Executor

# This is a dead simple workflow that calls two shell scripts
shell <<~SHELLSTEP
  echo "I have no idea what's going on"
SHELLSTEP
shell "pwd"

# now add LLM prompt support. RubyLLM? Ollama?
