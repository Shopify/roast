# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat { no_display! }
end

execute(:refine_text) do
  chat(:improve) do |_, text|
    <<~PROMPT
      Improve this text by making it more concise and clear.
      Keep the same meaning but use fewer words.

      Text: #{text}

      Return only the improved text, nothing else.
    PROMPT
  end

  ruby do |_, _, index|
    puts "\n--- Iteration #{index} ---"
    puts chat!(:improve).response
    break! if index >= 3
  end

  outputs { chat!(:improve).text }
end

execute do
  initial_text = <<~TEXT
    It is widely known and commonly accepted by many people that
    regular physical exercise and activity is generally beneficial
    and helpful for maintaining good health and overall wellness.
  TEXT

  puts "=== Original Text ==="
  puts initial_text

  repeat(:refinement, run: :refine_text) { initial_text }

  ruby do
    puts "\n=== Final Result ==="
    puts repeat!(:refinement).value

    puts "\n=== All Iterations ==="
    all_versions = collect(repeat!(:refinement).results) do
      chat!(:improve).response
    end

    all_versions.each_with_index do |version, i|
      puts "\nIteration #{i}:"
      puts version
    end
  end
end
