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
  # Call a subroutine with `call`
  call(:hello, run: :capitalize_a_word) { "Hello" }
  call(:world, run: :capitalize_a_word) { "World" }

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
    original = from(call!(:hello)) { cmd!(:to_original).out.strip }
    upper = from(call!(:hello)) { cmd!(:to_upper).out.strip }
    lower = from(call!(:hello)) { cmd!(:to_lower).out.strip }
    "echo \"#{original} --> #{upper} --> #{lower}\""
  end

  cmd do
    # You can also grab the `call`'s output once and pass it to multiple `from` invocations.
    my_scope = call!(:world)
    original = from(my_scope) { cmd!(:to_original).out.strip }
    upper = from(my_scope) { cmd!(:to_upper).out.strip }
    lower = from(my_scope) { cmd!(:to_lower).out.strip }
    "echo \"#{original} --> #{upper} --> #{lower}\""
  end
end
