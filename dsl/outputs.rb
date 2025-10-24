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
  outputs { "Upper: #{cmd!(:to_upper).out}" } # `outputs` can return any kind of value
end

execute do
  # Call a subroutine with `call` or `map`
  call(:hello, run: :capitalize_a_word) { "Hello" }

  cmd do
    upper = from(call!(:hello))
    "echo \"#{upper}\""
  end
end
