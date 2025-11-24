# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    print_all!
  end
end

execute(:capitalize_a_random_word) do
  cmd(:word) { "shuf /usr/share/dict/words -n 1" }
  cmd(:capitalize) do |my, value_from_call|
    # Optional second block argument lets you use a value passed to the sub-executor by `call`
    # from withing any cog in the sub-executor
    word = value_from_call || cmd!(:word).text
    my.command = "/bin/sh"
    my.args << "-c"
    my.args << "/bin/echo \"#{word}\" | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  cmd(:before) { "echo '--> before'" }

  # First positional argument is always the (optional) cog name
  # Keyword argument "run" is the (required) scope name of the executor to run
  call(:first_call, run: :capitalize_a_random_word)
  call(:other_named_call, run: :capitalize_a_random_word)
  call(run: :capitalize_a_random_word) # anonymous call cog

  cmd { "echo '---'" }

  # Can invoke a sub-executor with an executor-scoped value, that will be passed to each cog's input proc in that scope
  call(run: :capitalize_a_random_word) do |my|
    my.value = "scope value: roast"
  end

  # Shorthand input coercion for passing a scope value
  call(run: :capitalize_a_random_word) { "scope value: other" }

  cmd(:after) { "echo '--> after'" }
end
