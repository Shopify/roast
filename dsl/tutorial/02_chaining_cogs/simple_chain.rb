# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates basic chaining of cogs.
# Data flows: sample text → analysis → summary → formatted output

config do
  chat do
    model "gpt-4o-mini"
    provider :openai
  end
end

execute do
  # Sample data embedded in the workflow
  customer_feedback = <<~TEXT
    I've been using your product for 3 months now. The interface is
    really intuitive and I love the dark mode. However, the mobile
    app crashes frequently when I try to upload photos. Also, the
    export feature could be faster... it takes forever to download
    large files! Overall though, I'm happy with the purchase and
    would recommend it to friends.
  TEXT

  # Step 1: Analyze the feedback
  chat(:analyze) do
    <<~PROMPT
      Analyze this customer feedback and identify:
      1. Positive points
      2. Issues/problems
      3. Feature requests

      Feedback:
      #{customer_feedback}

      Provide a structured analysis.
    PROMPT
  end

  # Step 2: Create a concise summary
  # Note how we access the previous cog's output
  chat(:summarize) do
    analysis = chat!(:analyze).response

    <<~PROMPT
      Take this feedback analysis and create a 2-3 sentence
      summary suitable for a product team standup:

      #{analysis}

      Focus on actionable items.
    PROMPT
  end

  # Step 3: Format and display the results
  ruby(:display) do
    puts "\n" + "=" * 70
    puts "CUSTOMER FEEDBACK ANALYSIS"
    puts "=" * 70

    puts "\nORIGINAL FEEDBACK:"
    puts "-" * 70
    puts customer_feedback

    puts "\nEXECUTIVE SUMMARY:"
    puts "-" * 70
    puts chat!(:summarize).text

    puts "\nDETAILED ANALYSIS:"
    puts "-" * 70
    puts chat!(:analyze).text

    puts "=" * 70 + "\n"

    # Return a value that could be used by subsequent steps
    {
      status: "complete",
      feedback_length: customer_feedback.length,
      summary_lines: chat!(:summarize).lines.length,
    }
  end
end
