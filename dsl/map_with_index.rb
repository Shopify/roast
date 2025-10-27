# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    print_all!
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
  map(:some_name, run: :capitalize_a_word) { words }
end
