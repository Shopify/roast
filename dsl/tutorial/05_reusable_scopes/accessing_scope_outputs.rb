# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This workflow demonstrates accessing specific cog outputs from a called scope.
# It shows how to use from() with a block to extract outputs from multiple cogs,
# and how the default return value is the final cog's output when no outputs! block is provided.

config do
  chat do
    model "gpt-4o-mini"
    no_show_response!
  end

  chat(:final_summary) do
    show_response!
  end
end

# Define a scope that processes text through multiple transformations
# Note: No outputs! block, so the default return is the last cog's output
execute(:process_text) do
  chat(:extract_keywords) do |_, text|
    <<~PROMPT
      Extract 3-5 key words or phrases from this text, in JSON form: `{ keywords: [ ... ] }`
      #{text}
    PROMPT
  end

  chat(:determine_sentiment) do |_, text|
    <<~PROMPT
      What is the sentiment of this text? Answer with just one word: positive, negative, or neutral.
      #{text}
    PROMPT
  end

  chat(:generate_title) do |_, text|
    <<~PROMPT
      Generate a short, catchy title (5-7 words) for this text:
      #{text}
    PROMPT
  end

  chat(:word_count) do |_, text|
    "Count the approximate number of words in this text and respond with just the number: #{text}"
  end
end

# Main workflow
execute do
  ruby do
    puts "=" * 70
    puts "ACCESSING SCOPE OUTPUTS EXAMPLE"
    puts "=" * 70
  end

  # Process a sample text
  call(:result, run: :process_text) do
    <<~TEXT
      Artificial intelligence is revolutionizing software development.
      Machine learning models can now write code, detect bugs, and
      suggest improvements. This technology empowers developers to
      build better software faster than ever before.
    TEXT
  end

  # The default return value (without outputs!) is the last cog's output
  ruby do
    puts "\nDEFAULT RETURN VALUE (last cog in scope):"
    word_count = from(call!(:result)).text
    puts "Word count: #{word_count}"
  end

  # Use from() with a block to access specific cogs from the scope
  ruby do
    puts "\nACCESSING SPECIFIC COGS:"

    # The block runs in the context of the called scope
    # You can access any cogs defined in that scope
    keywords, sentiment, title = from(call!(:result)) do
      [
        chat!(:extract_keywords).json![:keywords],
        chat!(:determine_sentiment).text,
        chat!(:generate_title).text,
      ]
    end

    puts "Keywords: #{keywords.join(", ")}"
    puts "Sentiment: #{sentiment}"
    puts "Title: #{title}"
  end

  # Create a final summary combining the extracted information
  chat(:final_summary) do
    keywords, sentiment, title, word_count = from(call!(:result)) do
      [
        chat!(:extract_keywords).json![:keywords],
        chat!(:determine_sentiment).text,
        chat!(:generate_title).text,
        chat!(:word_count).text,
      ]
    end

    <<~PROMPT
      Create a brief meta-summary (2-3 sentences) using this analysis:

      Title: #{title}
      Keywords: #{keywords.join(", ")}
      Sentiment: #{sentiment}
      Word Count: #{word_count}
    PROMPT
  end

  ruby do
    puts "\n" + "=" * 70
    puts <<~NOTE
      KEY POINTS:
      - Without outputs!, the default return is the last cog's output
      - Use from(call!(:name)) to access the default return value
      - Use from(call!(:name)) { ... } with a block to access specific cogs
      - The block runs in the context of the called scope
      - You can extract outputs from multiple cogs in one call
    NOTE
  end
end
