# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    print_all!
  end
end

execute(:capitalize_a_word) do
  cmd(:capitalize) do |my, word|
    word ||= cmd(:word).out.strip
    my.command = "sh"
    my.args << "-c"
    my.args << "echo '#{word}' | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  words = ["hello", "world", "goodnight", "moon"]

  # WITHOUT MAP COG
  # You can use plain Ruby to generate a collection of cogs programmatically
  # This is equivalent to simply defining each of the cogs explicitly, one by one
  # In this case, four copies of the `call` cog invoking :capitalize_a_word
  words.each { |word| call(:capitalize_a_word) { word } }

  cmd(:foo) { "echo" }

  # USING MAP COG
  # You can use the `map` cog to apply a scoped executor to each item in a collection of values
  map(:capitalize_a_word, :some_name) do |my|
    my.items = words
  end

  cmd { "echo" }

  # USING MAP COG (SHORTHAND)
  # - name of execute scope is required
  # - name of the map cog itself can be omitted (anonymous cog)
  # - items over which to map coerced from return value of input proc
  map(:capitalize_a_word) { words.reverse }
end
