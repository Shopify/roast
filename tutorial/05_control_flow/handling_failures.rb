# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates failure handling with both no_abort_on_failure! and no_fail_on_error!
# It shows how workflows can continue even when individual cogs fail.

config do
  # This chat cog might fail, but the workflow should continue
  chat(:followup) do
    no_abort_on_failure!
    no_display!
  end

  # This command might return non-zero, but that's not a failure
  cmd(:grep) do
    no_fail_on_error!
    no_display!
  end
end

execute do
  # Step 1: Ask LLM to make up some data and return it as JSON
  chat(:generate_data) do
    <<~PROMPT
      Make up a simple shopping list with 3-5 items as a JSON object
      `{ items: [ name: ..., quantity: ... ] }`.
    PROMPT
  end

  # Step 2: Ask a follow-up question, but fail if the original response didn't include "milk"
  chat(:followup) do
    shopping_list_items = chat!(:generate_data).json![:items].map { |it| it[:name].downcase }
    fail! unless shopping_list_items.include?("milk")

    <<~PROMPT
      Based on this shopping list:
      #{chat!(:generate_data).text}

      Suggest a recipe that uses milk from the list.
    PROMPT
  end

  # Step 3: Run a command that might fail (grep returns non-zero when no matches)
  cmd(:grep) do |my|
    my.command = "grep -i eggs"
    my.stdin = chat!(:generate_data).text
  end

  # Step 4: Print summary results
  ruby do
    puts "\n" + "=" * 70
    puts "WORKFLOW RESULTS"
    puts "=" * 70

    shopping_list = chat!(:generate_data).json!
    puts "\nGenerated shopping list:"
    shopping_list[:items].each { |it| puts "- #{it[:name]}: #{it[:quantity]}" }

    if chat?(:followup)
      puts "\n✓ Follow-up succeeded (milk was in the list):"
      puts chat!(:followup).text
    else
      puts "\n✗ Follow-up failed (milk was not in the list)"
    end

    if cmd!(:grep).status.exitstatus == 0
      puts "\n✓ Grep found matches:"
      puts cmd!(:grep).text
    else
      puts "\n✗ Grep found no matches"
    end

    puts "\n" + "=" * 70
  end
end
