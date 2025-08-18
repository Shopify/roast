# typed: true
# frozen_string_literal: true
#: self as Roast::DSL::Executor

# This is a dead simple workflow that calls two shell scripts
shell <<~SHELLSTEP
  echo "I have no idea what's going on"
SHELLSTEP
shell "pwd"

# now add LLM prompt support. RubyLLM? Ollama?
agent {"Do some stuff"}

# How do we configure agents?
agent(:claude, ClaudeCodeProvider).config do |agent|
  agent.some_claude_specific_thing = true
  agent.print_response = true
end

# Ok I configured one, how do I reuse it? Which one is better?
# 1. Reuses `agent` syntax, but loses typing. Have to remember which agents are in play
# Can configure and then immediately use agent through fluent interface
agent(:claude) { "Do a thing" }

# 2. We could compile types in such a way that this is recognized as a valid method. Validation easier
# Definition of agent is likely part of workflow preamble, then agent calls are separate.
# No fluent interface. Is explicit config of workflow agents a bad thing?
claude { "Do a thing" }

# Current roast expects you to do some environment config for LLM auth and setup.
# This is environment specific and probably shouldn't be directly encoded into the workflow
# Workflow should at most do "call this model with these params" but authentication should
# already be set up.
# If we're already preconfiguring models, is there any reason to require this every time, or
# should model provider gems just give you (for example) a `claude` method like above that has
# already implemented all of the standard configs and knows to look at roast env for auth.

# Counter: what if I want to use the same model but with different configs?
# Is there a "workflow default agent" and a "model default agent"? Sometimes these are the same,
# but in multiagent workflows may want to change it up

# Call the default claude agent, with default configs.
# Always returns the same agent instance (though resuming session is dependent on agent implementation)
claude { "Do a thing" }

claude.config do |config| # Configures the default agent.
  model = :haiku
end

# Configures a separate agent instance from the default.
# Does not inherit anything, starts from the default configs in the agent implementation,
# does not include modifications from user in workflow
claude(:modified_agent).config do |config|
  agent.prepend_prompt "Do this too! And don't do this!"
end

claude(:modified_agent) { "Do this differently" }

# But now I've basically landed back at the `agent` api, but with a ton of different names lol
