# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates parameterized scopes.
# It shows how to pass values to scopes and use them within the scope's cogs.

config do
  chat do
    model "gpt-4o-mini"
  end
end

# Define a scope that analyzes text
execute(:analyze_text) do
  chat(:analysis) do |_, text|
    # The text parameter comes from the call cog's input block
    <<~PROMPT
      Analyze this text and provide:
      1. Word count (approximate)
      2. Main topic
      3. Sentiment (positive/negative/neutral)

      Text: #{text}

      Return your analysis as a brief summary.
    PROMPT
  end

  outputs! { chat!(:analysis).response }
end

# Main workflow
execute do
  ruby { puts "=" * 70 }
  ruby { puts "PARAMETERIZED SCOPES EXAMPLE" }
  ruby { puts "=" * 70 }

  # Analyze different texts using the same scope
  call(:analysis1, run: :analyze_text) do
    "The quick brown fox jumps over the lazy dog."
  end

  call(:analysis2, run: :analyze_text) do
    "Artificial intelligence is transforming how we build software."
  end

  call(:analysis3, run: :analyze_text) do
    "I'm disappointed with the results of this experiment."
  end

  # Display all results
  ruby do
    puts "\nANALYSIS 1:"
    puts from(call!(:analysis1))

    puts "\nANALYSIS 2:"
    puts from(call!(:analysis2))

    puts "\nANALYSIS 3:"
    puts from(call!(:analysis3))
  end

  ruby { puts "\n" + "=" * 70 }

  ruby do
    puts <<~NOTE
      KEY POINTS:
      - Pass values to scopes using call's input block
      - Access the value as the second parameter in cog blocks
      - The same scope can process different inputs
      - This makes scopes reusable and composable
    NOTE
  end

  ruby { puts "=" * 70 }
end
