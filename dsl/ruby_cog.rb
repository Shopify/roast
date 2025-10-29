# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

class MyClass
  class << self
    def add_stuff(a, b)
      a + b
    end
  end
end

config do
  cmd { print_all! }
end

execute do
  cmd(:roast) { "echo Roast" }

  # The `ruby` cog just passes the return value from its input block directly to its output.
  # Letting you write whatever ruby code you want to generate that output
  ruby(:whatever) do
    # Do whatever you want in this block
    value = cmd!(:roast).out
    puts "Hello, #{value.upcase}"
    puts "Calling a method: #{MyClass.add_stuff(3, 4)}"
    # The value you return will be exposed as the .value attribute on the cog's output
    1..5
  end

  cmd(:numbers) do |my|
    my.command = "echo"
    value = ruby!(:whatever).value.map { |n| n.to_s * n }
    my.args = value
  end
end
