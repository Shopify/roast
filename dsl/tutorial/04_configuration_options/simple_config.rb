# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This workflow demonstrates basic configuration of models and providers.
# It shows how to set global defaults and override them for specific steps.

config do
  # Set default configuration for all chat cogs
  chat do
    model "gpt-4o-mini"
    provider :openai
    show_prompt! # Show prompts for all chat cogs
  end

  # Override for a specific cog - use more capable model
  chat(:analyze_trends) do
    model "gpt-5"
  end

  # Override for a specific cog - hide response
  chat(:format_report) do
    no_show_response!
  end
end

execute do
  # This cog uses the global config (gpt-4o-mini)
  chat(:extract_info) do
    <<~PROMPT
      Extract the key information from this text and format it as a bullet list:

      "Our Q4 results show revenue of $2.5M, up 15% from Q3. Customer count increased to 1,200
      (from 950), and average deal size grew from $2,000 to $2,300. However, churn rate rose
      slightly to 8% from 7%."
    PROMPT
  end

  # This cog uses the specific override configured above (gpt-5)
  chat(:analyze_trends) do
    <<~PROMPT
      Analyze these metrics and identify the most important trends:

      #{chat!(:extract_info).text}

      Focus on: growth patterns, concerning signals, and strategic implications.
    PROMPT
  end

  # This cog uses the specific configuration above (hidden response)
  chat(:format_report) do
    <<~PROMPT
      Format this analysis as a structured report with clear sections:

      #{chat!(:analyze_trends).text}
    PROMPT
  end

  # Final step: display the formatted report
  ruby(:display) do
    puts "\n" + "=" * 70
    puts "QUARTERLY ANALYSIS REPORT"
    puts "=" * 70
    puts chat!(:format_report).response
    puts "=" * 70 + "\n"
  end
end
