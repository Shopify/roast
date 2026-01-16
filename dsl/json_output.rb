# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd { display! }
end

execute do
  cmd(:json) do |my|
    my.command = "echo"
    my.args << <<~JSON
      {
        "hello": "world",
        "letters": [
          "aaa",
          "bbb"
        ]
      }
    JSON
  end

  ruby do
    puts "RAW OUTPUT: #{cmd!(:json).text}"
    puts "SOME VALUE FROM PARSED OUTPUT: #{cmd!(:json).json![:letters].first}"
  end
end
