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
