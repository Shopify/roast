# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates basic named execute scopes and the call cog.
# It shows how to define reusable logic and invoke it multiple times.

config {}

# Define a reusable scope that displays a separator
execute(:print_separator) do
  ruby { puts "=" * 70 }
end

# Define a scope that generates a random word
execute(:random_word) do
  cmd(:word) { "shuf /usr/share/dict/words -n 1" }

  outputs! { cmd!(:word).text }
end

# Main workflow
execute do
  call(run: :print_separator)

  ruby { puts "REUSABLE SCOPES EXAMPLE" }

  call(run: :print_separator)

  # Call the random_word scope three times
  ruby { puts "\nGenerating three random words:" }

  call(:word1, run: :random_word)
  call(:word2, run: :random_word)
  call(:word3, run: :random_word)

  # Extract and display the results
  ruby do
    word1 = from(call!(:word1))
    word2 = from(call!(:word2))
    word3 = from(call!(:word3))

    puts "  1. #{word1}"
    puts "  2. #{word2}"
    puts "  3. #{word3}"
  end

  call(run: :print_separator)

  ruby do
    puts <<~NOTE
      KEY POINTS:
      - Named scopes don't run automatically - they must be called
      - The same scope can be called multiple times
      - Each call is independent with its own execution context
      - Use outputs! to return values from a scope
      - Use from() to extract the returned value
    NOTE
  end

  call(run: :print_separator)
end
