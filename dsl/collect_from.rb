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
  # Call a subroutine with `call` or `map`
  call(:hello, run: :capitalize_a_word) { "Hello" }
  call(:world, run: :capitalize_a_word) { "World" }
  map(:other_words, run: :capitalize_a_word) { ["Goodnight", "Moon"] }

  cmd do
    # Normally, you can only reference the output of cogs that run in the same executor scope.
    begin
      # There is no :to_upper cog that this could sensibly be referring to
      cmd(:to_upper)
    rescue Roast::DSL::CogInputManager::CogDoesNotExistError
      puts "Could not access :to_upper directly"
    end

    # Using `from`, you can access cogs from the executor scope that was run by a specific named `call`.
    # The block you pass to `from` runs in the input context of the specified scope, rather than the current scope.
    original = from(call!(:hello)) { cmd!(:to_original).out }
    upper = from(call!(:hello)) { cmd!(:to_upper).out }
    lower = from(call!(:hello)) { cmd!(:to_lower).out }
    "echo \"#{original} --> #{upper} --> #{lower}\""
  end

  cmd do
    # You can also grab the `call`'s output once and pass it to multiple `from` invocations.
    my_scope = call!(:world)
    original = from(my_scope) { cmd!(:to_original).out }
    upper = from(my_scope) { cmd!(:to_upper).out }
    lower = from(my_scope) { cmd!(:to_lower).out }
    "echo \"#{original} --> #{upper} --> #{lower}\""
  end

  cmd do
    # Using `collect`, you can access cogs from the executor scopes that were run by a specific named `map`.
    # The block you pass to `collect` runs in the input context of each specified scope.
    # `collect` returns an array containing the output of each invocation of that block.
    originals = collect(map!(:other_words)) { cmd!(:to_original).out }
    uppers = collect(map!(:other_words)) { cmd!(:to_upper).out }
    lowers = collect(map!(:other_words)) { cmd!(:to_lower).out }
    "echo \"#{originals.join(",")} --> #{uppers.join(",")} --> #{lowers.join(",")}\""
  end
end
