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
# target use case: three models, heavy lift, light work, summarize (opus, haiku, gemini)
# agent_type_foo comes from roast-agent-foo gem
agent_type_foo.define :code-writer do |agent (agent_type_foo_config_instance)|
    agent.model = "claude-opus"
    token_limit = 1m
    agent.before_prompt = "heads up"
    agent.after_prompt = "please write this json object..."
    agent.skip_permissions!
end

shell_script_step_gem.define :blah do |config|
    config.env = blah
end

agent.extend :code-writer, :code-analyzer do |agent|
    agent.after_prompt = "REMEMBER!!! Don't actually write any code, just make a plan."
end

agent.define :summarizer do |agent|
    agent.model = "gemini"
end

agent = agent_claude_opus

step_from_dir_name
code-writer step_name
code-analyzer do |agent|
    "WTF did you just write"
end
agent step_name
summarizer

# common agent step and common ruby step should both look like this
my_imported_plugin_step do |foo, bar|
    # config for step here
    # need: mapping for workflow output of previous steps
    foo = output.some_other_step
    bar = 5
end



if condition
    summarizer "thing"
    other_step
else
    # other thing
end


MyUtilClass.somethign_I_Think_is_useful

# MyStepClass < BaseRubyStep
# step_type :my_step
# see above about imported step types
ruby_step_type MyStepClass
MyVeryCustiomStep.call(workflow, other_param)


# in conditional stuff, need way to short-circuit workflow
if condition
    wrap_up
    summarize_short_Result
    stop_workflow!
end



state A do |graph|
    step_1
    step_2
    if foo
        transition graph.B
    else
        transition graph.C
    end
end

graph.node A do |node|
end

grand.edge A_B do |blah|
end


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
# workflow_output[:my_prompt] = <output of my_prompt step>

externally_defined_prompt

if output :my_prompt == "bleh"

# metafeatures (non-DSL)
- temporary directory for workflows to barf stuff into while working (first class place for steps to store output files)
  -  "write a markdown output using this template"
  - better json output parsing for coding agent
- support for non Openrouter compatible LLMs (Ollama)
- support for multiple models defined for different purposes
- 

# core roast = just vanilla ruby execution
# plugin that provides graph / state machine way to write workflows
# plugin that provides way to parse YAML workflow definitions

# core roast gives you:
# - how to execute ai agent steps
# - how to parse results
# - how to execute deterministic steps
# - how to hook up plugins / extensions / frontends
# - how to handle workflow ouput object / data
# - how to parse json output...
# - EXTREMELY MINIMAL STEPS CONCEPT.
#   - roast is aware of units of work
#   - roast provides a way to capture outputs from steps, pass state between steps, etc.
# - basic resume functionality?



