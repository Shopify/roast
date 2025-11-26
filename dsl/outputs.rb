# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  global { exit_on_error! }
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
    break! # the `outputs` will always be evaluated even if a cog breaks out of the execution scope
    my.command = "sh"
    my.args << "-c"
    my.args << "echo \"#{word}\" | tr '[:upper:]' '[:lower:]'"
  end
  outputs do |word|
    "Upper: #{cmd!(:to_upper).text} - Original: #{word}"
    # `outputs` can return any kind of value
  end
end

execute do
  # Call a subroutine with `call` or `map`
  call(:hello, run: :capitalize_a_word) { "Hello" }

  cmd do
    from_outputs = from(call!(:hello))
    explicit_value_access = from(call!(:hello)) { cmd!(:to_upper).text }
    "echo From Outputs: '\"#{from_outputs}\"\nExplicit Value Access: \"#{explicit_value_access}\"'"
  end
end
