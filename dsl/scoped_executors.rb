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
  cmd(:capitalize) do |my, word|
    # Optional second block argument lets you use the value passed to the sub-executor from withing any cog
    word ||= cmd(:word).out.strip
    my.command = "sh"
    my.args << "-c"
    my.args << "echo '#{word}' | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  cmd(:before) { "echo '--> before'" }

  # Can invoke a sub-executor simply, just by its name
  execute { :capitalize_a_random_word }
  execute { :capitalize_a_random_word }

  # Can invoke a sub-executor with an executor-scoped value, that will be passed to each cog's input proc in that scope
  execute do |my|
    my.scope = :capitalize_a_random_word
    my.value = "scope: roast"
  end

  # Shorthand input coercion for passing a scope value
  execute { [:capitalize_a_random_word, "scope: other"] }

  cmd(:after) { "echo '--> after'" }
end
