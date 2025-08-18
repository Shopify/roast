agent "Do some shit"
process_some_shit # ruby / shell file in standard dir or prompt in dir
prompt "Summarize my shit"

ruby my_step_name
prompt "summarizr this"
prompt my_prompt_dir
agent "re-write tests"
shell fix_sorbet

fix_sorbet
prompt "summarizr this"
prompt my_prompt_dir
agent "re-write tests"

# every LLM step is now powered by an agent definition of some kind
# (every LLM implementation is provided by a plugin gem)
# (LLM configuration is custom to each LLM type / plugin - agent definitions hide all the complexity of the specific provider)
# Roast doesn't genericize agent config across multiple providers - Roast only sees agent interface and the 
# agent system hides the provider specific stuff
# agent gems shouldn't directly output to cli, should pass back to Roast and Roast should decide verbosity and output
# toy example
agent.define :prompt do |agent|

end

# user defined agents, with system prompt
agent.define :code-writer do |agent|
    agent.model = "claude-opus"
    token_limit = 1m
    agent.before_prompt = "heads up"
    agent.after_prompt = "please write this json object..."
    agent.skip_permissions!
end

agent.extend :code-writer, :code-analyzer do |agent|
    agent.after_prompt = "REMEMBER!!! Don't actually write any code, just make a plan."
end

agent.define :summarizer do |agent|
    agent.model = "gemini"
end

code-writer step_name
code-analyzer do |agent|
    "WTF did you just write"
end
summarizer

# notes
# - library of steps where I don't care what kind they are
# - ??? lack of confusion around which steps are ai vs deterministic
# - different types of AI steps - should not be confusing which ones are which kind
# - step names should not have meta control characters
# - in line stuff like shell commands and prompts -- should we even have them? clean in-line syntax

prompt :my_prompt do
  """
  this is a long prompt

  many lines
  """
end

externally_defined_prompt

if output :my_prompt == "bleh"

# metafeatures (non-DSL)
- temporary directory for workflows to barf stuff into while working (first class place for steps to store output files)
  -  "write a markdown output using this template"
  - better json output parsing for coding agent
- support for non Openrouter compatible LLMs (Ollama)
- support for multiple models defined for different purposes
- 
