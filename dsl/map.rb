# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    display!
  end
end

execute(:capitalize_a_word) do
  cmd(:capitalize) do |my, word|
    # Use the `fail!` method in a cog's input proc to terminate the cog with a failure state
    # e.g., if a condition prevents its successful execution.
    # If `fail!` is called, the input proc will immediately terminate.
    # The entire workflow may or may not terminate as a result, based on its configuration and the cog's configuration.
    fail! unless word.present?
    my.command = "sh"
    my.args << "-c"
    my.args << "echo \"#{word}\" | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  words = ["hello", "world", "goodnight", "moon"]

  # WITHOUT MAP COG
  # You can use plain Ruby to generate a collection of cogs programmatically
  # This is equivalent to simply defining each of the cogs explicitly, one by one
  # In this case, four copies of the `call` cog invoking :capitalize_a_word
  words.each { |word| call(run: :capitalize_a_word) { word } }

  cmd(:foo) { "echo" }

  # USING MAP COG
  # You can use the `map` cog to apply a scoped executor to each item in a collection of values
  map(:some_name, run: :capitalize_a_word) do |my|
    my.items = words
  end

  cmd { "echo" }

  # USING MAP COG (SHORTHAND)
  # - name of execute scope is required
  # - name of the map cog itself can be omitted (anonymous cog)
  # - items over which to map coerced from return value of input proc
  map(run: :capitalize_a_word) { words.reverse }

  # ACCESSING THE OUTPUT OF A SPECIFIC MAP ITERATION
  ruby do
    puts ""
    puts "#{words[2]} -> #{from(map!(:some_name).iteration(2)) { cmd!(:capitalize).text }}"
  end
end
