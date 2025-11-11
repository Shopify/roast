# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Documentation Generator
#
# This workflow analyzes Ruby code and generates or updates documentation
# including README files, code comments, and API documentation.
# Demonstrates file I/O operations, code analysis, and content generation.
#
# Run with: bundle exec bin/roast execute examples/docs_generator.rb --executor dsl

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Analyze existing documentation
  agent(:analyze_existing_docs) do
    "Examine the current documentation in this project. Check README.md, any other .md files, and look for inline code documentation. Assess what documentation exists and what might be missing."
  end

  # Step 2: Analyze code structure for documentation needs
  agent(:analyze_code_structure) do
    "Analyze the main Ruby files in lib/ to understand the project's API and structure. Identify classes, modules, and key methods that should be documented. Focus on public interfaces."
  end

  # Step 3: Process analysis and determine documentation needs
  ruby(:determine_doc_needs) do
    existing_docs = agent!(:analyze_existing_docs).response
    code_structure = agent!(:analyze_code_structure).response

    # Simple analysis of what needs documentation
    needs_readme = existing_docs.downcase.include?("readme") && existing_docs.downcase.include?("missing")
    needs_api_docs = code_structure.downcase.include?("undocumented") || code_structure.downcase.include?("missing")
    needs_examples = !existing_docs.downcase.include?("example")

    {
      needs_readme_update: needs_readme,
      needs_api_docs: needs_api_docs,
      needs_examples: needs_examples,
      timestamp: Time.now.iso8601
    }
  end

  # Step 4: Generate documentation improvements
  agent(:generate_docs) do |_, params|
    needs = ruby!(:determine_doc_needs).value
    code_analysis = agent!(:analyze_code_structure).response

    if needs[:needs_api_docs] || needs[:needs_readme_update]
      "Based on the code analysis, generate improved documentation. Create a better README section that explains the main components and how to use them. Focus on practical examples and clear explanations. Keep it concise but helpful.\n\nCode structure found:\n#{code_analysis.split("\n").first(10).join("\n")}"
    else
      "The documentation appears comprehensive. Suggest minor improvements or additional examples that could enhance clarity."
    end
  end

  # Step 5: Display results and recommendations
  ruby(:display_results) do
    needs = ruby!(:determine_doc_needs).value
    generated_docs = agent!(:generate_docs).response

    puts "\n" + "=" * 50
    puts "DOCUMENTATION ANALYSIS REPORT"
    puts "=" * 50
    puts "Analysis Date: #{needs[:timestamp]}"
    puts

    if needs[:needs_readme_update]
      puts "📄 README needs updating"
    else
      puts "✅ README appears adequate"
    end

    if needs[:needs_api_docs]
      puts "📚 API documentation needed"
    else
      puts "✅ API documentation appears adequate"
    end

    if needs[:needs_examples]
      puts "💡 More examples would be helpful"
    else
      puts "✅ Examples appear sufficient"
    end

    puts "\n" + "-" * 40
    puts "DOCUMENTATION SUGGESTIONS"
    puts "-" * 40
    puts generated_docs
    puts "\n" + "=" * 50

    {
      improvements_needed: needs[:needs_readme_update] || needs[:needs_api_docs] || needs[:needs_examples],
      analysis_complete: true
    }
  end
end