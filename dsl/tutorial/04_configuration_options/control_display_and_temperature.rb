# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This workflow demonstrates controlling what gets displayed during execution.
# Shows how to use show_prompt!, no_show_prompt!, show_response!, no_show_response!, and temperature.

config do
  chat do
    model "gpt-4o-mini"
    show_prompt! # Show all prompts by default
    no_show_response! # But hide responses by default
  end

  # Configure specific cogs with custom settings
  chat(:generate_ideas) do
    temperature(0.9) # Higher temperature for creative brainstorming
  end

  chat(:extract_names) do
    temperature(0.0) # Low temperature for reliable extraction
  end

  chat(:evaluate_names) do
    no_show_prompt! # Hide prompt for this step
  end

  chat(:pick_best) do
    show_prompt! # Explicit show (redundant but clear)
    show_response! # Show the final decision
    temperature(0.3) # Low-medium for consistent evaluation
  end
end

execute do
  # Step 1: Generate creative content (high temperature configured above)
  # The prompt is shown, response is hidden (our configured global default)
  chat(:generate_ideas) do
    <<~PROMPT
      Brainstorm 5 creative names for a new project management tool focused on AI workflows.

      Make them memorable, pronounceable, and available as .com domains (don't verify, just guess).
    PROMPT
  end

  # Step 2: Extract structured data (low temperature configured above)
  # The prompt is shown, response is hidden (our configured global default)
  chat(:extract_names) do
    ideas = chat!(:generate_ideas).response
    <<~PROMPT
      Extract just the names from this brainstorming output, format as JSON: `{ names: [...] }`

      #{ideas}
    PROMPT
  end

  # Step 3: Evaluate each name
  # Prompt hidden (configured above), response hidden (global default)
  chat(:evaluate_names) do
    names = chat!(:extract_names).json![:names]
    <<~PROMPT
      Evaluate these product names for:
      1. Memorability (1-10)
      2. Professionalism (1-10)
      3. Relevance to AI workflows (1-10)

      Names:
      - #{names.join("\n- ")}
    PROMPT
  end

  # Step 4: Pick the best name
  # Both prompt and response shown (configured above)
  chat(:pick_best) do
    <<~PROMPT
      Based on these evaluations, pick the single best name and explain why in 2-3 sentences:

      #{chat!(:evaluate_names).text}
    PROMPT
  end

  # Summary of what was displayed:
  ruby(:display_summary) do
    puts "\n" + "=" * 70
    puts "DISPLAY CONTROL DEMONSTRATION"
    puts "=" * 70
    puts <<~SUMMARY

      What you saw:
      - ✓ Prompts for steps 1-2 (global show_prompt!)
      - ✗ Responses for steps 1-3 (global no_show_response!)
      - ✗ Prompt for step 3 (configured with no_show_prompt!)
      - ✓ Prompt and response for step 4 (configured with show_response!)
      - ✓ LLM stats for every step (unconfigured; Roast default)

      Temperature settings (all configured in config block):
      - Step 1: 0.9 (higher, for creative brainstorming)
      - Step 2: 0.0 (low, for reliable extraction)
      - Step 4: 0.3 (low-medium, for consistent evaluation)
    SUMMARY
    puts "=" * 70 + "\n"
  end
end
