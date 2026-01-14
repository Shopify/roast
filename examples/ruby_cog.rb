# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

class MyClass
  class << self
    def add_stuff(a, b)
      a + b
    end
  end
end

config do
  cmd { display! }
end

execute do
  cmd(:roast) { "echo Roast" }

  # The `ruby` cog just passes the return value from its input block directly to its output.
  # Letting you write whatever ruby code you want to generate that output
  ruby(:whatever) do
    # Do whatever you want in this block
    value = cmd!(:roast).text
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

  ruby(:advanced_hash_output) do
    {
      some_number: 7,
      some_string: "Hello, world!",
      multiply: proc { |a, b| a * b },
    }
  end

  ruby do
    result = ruby!(:advanced_hash_output) #: untyped

    # If the output's `value` is a Hash, you can access its items directly from the output object
    puts "Some Number + 1: #{result[:some_number] + 1}"
    # You can also access its items as getter methods on the output object
    puts "Some String to Upper: #{result.some_string.upcase}"
    # And, if one of those items is a proc, you can call it directly on the output object
    puts "Multiply 4 * 3: #{result.multiply(4, 3)}"
  end

  ruby(:advanced_object_output) do |my|
    my.value = <<~STRING
      This is a long block of test
      Consisting of many lines
      Three, to be precise
    STRING
  end

  ruby do
    result = ruby!(:advanced_object_output) #: untyped

    # You can also call methods on the output's `value` directly, regardless of its type
    puts "The long string has #{result.lines.length} lines"
    puts "And it has #{result.length} characters"
  end
end
