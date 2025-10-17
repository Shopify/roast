# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd {
    print_all!
  }
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
  words.each { |word| execute { [ :capitalize_a_word, word ] } }

  cmd(:foo) { "echo" }

  # USING MAP COG
  # You can use the special `map` cog to instruct the workflow executor to apply a scoped executor
  # to each item in a collection of values
  map(:some_name, :capitalize_a_word) do |my|
    my.items = words
  end

  cmd { "echo" }

  # USING MAP COG (SHORTHAND)
  # - name of execute scope taken to be the same as the name of the map
  # - items coerced from return value of input proc
  map(:capitalize_a_word) { words.reverse }
end
