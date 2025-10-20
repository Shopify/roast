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
    word = value_from_call || cmd(:word).out.strip
    my.command = "/bin/sh"
    my.args << "-c"
    my.args << "/bin/echo \"#{word}\" | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  cmd(:before) { "echo '--> before'" }

  # First argument to `call` is the executor scope to run
  # Second argument is the (optional) cog name
  call(:capitalize_a_random_word, :first_call)
  call(:capitalize_a_random_word, :other_named_call)
  call(:capitalize_a_random_word) # anonymous call cog

  cmd { "echo '---'" }

  # Can invoke a sub-executor with an executor-scoped value, that will be passed to each cog's input proc in that scope
  call(:capitalize_a_random_word) do |my|
    my.value = "scope value: roast"
  end

  # Shorthand input coercion for passing a scope value
  call(:capitalize_a_random_word) { "scope value: other" }

  cmd(:after) { "echo '--> after'" }
end
