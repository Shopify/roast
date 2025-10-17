# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  cmd do
    print_all!
  end
end

# TODO: there is no way to execute this block yet...
execute(:capitalize_a_random_word) do
  cmd(:word) { "shuf /usr/share/dict/words -n 1" }
  cmd(:capitalize) do |my|
    word = cmd(:word).out.strip
    my.command = "sh"
    my.args << "-c"
    my.args << "echo '#{word}' | tr '[:lower:]' '[:upper:]'"
  end
end

execute do
  cmd(:whatever) { "echo whatever" }
end
