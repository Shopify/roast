# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    display!
  end
end

execute(:capitalize_a_word) do
  cmd(:capitalize) do |my, word, index|
    fail! unless word.present?
    my.command = "sh"
    my.args << "-c"
    # When this execution scope is called by the `map` cog, the optional 'index' argument to this block
    # will contain the index of its element in the enumerable on which `map` is invoked
    my.args << "echo \"[#{index}] #{word}\" | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  words = ["hello", "world", "goodnight", "moon"]

  # When calling an execute scope with `map`, the index of the item in the enumerable
  # will be provided to the cogs in that scope
  map(:some_name, run: :capitalize_a_word) { words }

  cmd { "echo" }

  # When calling an execute scope with `call`, the cogs in that scope will receive 0 as the index value by default
  call(run: :capitalize_a_word) { "default" }

  call(run: :capitalize_a_word) do |my|
    my.value = "specific"
    # It is possible to specify a custom index value when invoking `call`
    my.index = 23
  end

  cmd { "echo" }

  # `map` will also take a custom 'initial_index' value, at which to start the value of 'index' passed
  # to the executors it invokes. This parallels the syntax of Ruby's `items.map.with_index(initial_value) { ... }`
  map(run: :capitalize_a_word) do |my|
    my.items = words[1, 2]
    my.initial_index = 8
  end
end
