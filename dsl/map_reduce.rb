# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd { display! }
  cmd(/to_/) { no_display! }
end

execute(:capitalize_a_word) do
  cmd(:to_original) { |_, word| "echo \"#{word}\"" }
  cmd(:to_upper) do |my, word|
    my.command = "sh"
    my.args << "-c"
    my.args << "echo \"#{word}\" | tr '[:lower:]' '[:upper:]'"
  end
  cmd(:to_lower) do |my, word|
    my.command = "sh"
    my.args << "-c"
    my.args << "echo \"#{word}\" | tr '[:upper:]' '[:lower:]'"
  end
end

execute do
  # Call a subroutine with `map`
  map(:words, run: :capitalize_a_word) { ["Hello", "World"] }

  cmd do
    # Use `reduce` to apply a block to the input context of each executor scope run by `map` in turn.
    # The return value of each invocation of the block will be passed as the 'accumulator' to the next invocation.
    # You can provide an optional initial value for the accumulator as the second argument to `reduce`.
    # If an initial value is present, the return type is non-nilable. If absent, the return type is nilable.
    words = reduce(map!(:words), "lower case words:") { |acc| acc + " " + cmd!(:to_lower).text }
    "echo \"#{words}\""
  end
end
