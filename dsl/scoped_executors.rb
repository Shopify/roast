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
  cmd(:capitalize) do |my|
    word = cmd(:word).out.strip
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
  cmd(:after) { "echo '--> after'" }
end
