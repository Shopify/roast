# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This workflow demonstrates using agent and chat cogs together.
# Agent reads/analyzes code, chat summarizes findings, ruby formats output.

config do
  agent do
    model "claude-3-5-haiku-20241022"
    provider :claude
  end

  chat do
    model "gpt-4o-mini"
    provider :openai
  end
end

execute do
  # Step 1: Agent performs detailed security review
  # The agent has access to file system and tools, though we're providing code directly here
  agent(:review_security) do
    <<~PROMPT
      You are a security-focused code reviewer. Analyze the files changed by the latest commit in this project
      and identify security vulnerabilities.

      For each issue found, explain:
      1. What the vulnerability is
      2. Why it's dangerous
      3. How to fix it
    PROMPT
  end

  # Step 2: Chat creates a prioritized summary
  # (There's no reason you couldn't use the `agent` to generate a summary;
  # we're just using `chat` here for illustration purposes.)
  chat(:prioritize) do
    review = agent!(:review_security).text
    <<~PROMPT
      Review this security analysis and create a prioritized action list.
      Rank issues by severity (Critical, High, Medium, Low).

      Security Review:
      #{review}

      Format as:
      - **[Severity]** Issue: Brief description
    PROMPT
  end

  # Step 3: Chat creates an executive summary
  chat(:summarize_for_executive) do
    review = agent!(:review_security).response
    <<~PROMPT
      Create a 2-3 sentence executive summary of this security review
      for a non-technical stakeholder:

      #{review}

      Focus on business impact and urgency.
    PROMPT
  end

  # Step 4: Ruby formats and displays the complete report
  ruby(:display_report) do
    puts "\n" + "=" * 80
    puts "CODE SECURITY REVIEW REPORT"
    puts "=" * 80

    puts "\nEXECUTIVE SUMMARY"
    puts "-" * 80
    puts chat!(:summarize_for_executive).response

    puts "\n\nPRIORITIZED ACTION ITEMS"
    puts "-" * 80
    puts chat!(:prioritize).response

    puts "\n\nDETAILED FINDINGS"
    puts "-" * 80
    puts agent!(:review_security).response

    puts "\n" + "=" * 80 + "\n"

    # Return structured data
    {
      report_generated_at: Time.now.iso8601,
      sections: ["executive_summary", "priority_summary", "detailed_findings"],
      total_length: agent!(:review_security).response.length,
    }
  end

  # Optional: Use the ruby cog's return value
  ruby(:check_report) do
    report_data = ruby!(:display_report).value

    if report_data[:total_length] > 0
      puts "✓ Report generated successfully at #{report_data[:report_generated_at]}"
    else
      puts "⚠ Warning: Report appears to be empty"
    end
  end
end
