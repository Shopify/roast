# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Code Health Analyzer
#
# This workflow analyzes a Ruby project for code quality, test coverage,
# and potential issues. It demonstrates practical use of DSL features like
# parallel execution, Ruby cogs for data processing, and tool integration.
#
# Run with: bundle exec bin/roast execute examples/code_health.rb --executor dsl

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Project structure analysis
  agent(:project_structure) do
    "Analyze this Ruby project structure. Check the directory layout, key files like Gemfile and Rakefile, and test organization. Provide a brief assessment of how well organized the project is."
  end

  # Step 2: Simple code quality check
  agent(:code_quality) do
    "Briefly analyze the Ruby code quality in lib/ directory. Check one or two files and comment on organization and patterns."
  end

  # Step 3: Compile simple metrics
  ruby(:compile_metrics) do
    project_analysis = agent!(:project_structure).response
    code_analysis = agent!(:code_quality).response

    # Simple scoring based on keywords in responses
    issue_indicators = ["error", "warning", "issue", "problem", "poor"]
    positive_indicators = ["good", "excellent", "well", "organized", "clean"]

    project_issues = issue_indicators.sum { |word| project_analysis.downcase.scan(word).count }
    project_positives = positive_indicators.sum { |word| project_analysis.downcase.scan(word).count }

    code_issues = issue_indicators.sum { |word| code_analysis.downcase.scan(word).count }
    code_positives = positive_indicators.sum { |word| code_analysis.downcase.scan(word).count }

    # Simple scoring (0-10)
    structure_score = [8 - project_issues + project_positives, 1].max.min(10)
    code_score = [8 - code_issues + code_positives, 1].max.min(10)
    overall_score = ((structure_score + code_score) / 2.0).round(1)

    {
      timestamp: Time.now.iso8601,
      structure_score: structure_score,
      code_score: code_score,
      overall_score: overall_score
    }
  end

  # Step 4: Format and display results
  ruby(:display_results) do
    metrics = ruby!(:compile_metrics).value

    puts "\n" + "=" * 50
    puts "CODE HEALTH ANALYSIS REPORT"
    puts "=" * 50
    puts "Analysis Date: #{metrics[:timestamp]}"
    puts "Overall Health Score: #{metrics[:overall_score]}/10"
    puts
    puts "Structure Score: #{metrics[:structure_score]}/10"
    puts "Code Quality Score: #{metrics[:code_score]}/10"

    status = case metrics[:overall_score]
             when 8..10 then "🟢 EXCELLENT"
             when 6..7 then "🟡 GOOD"
             when 4..5 then "🟠 NEEDS ATTENTION"
             else "🔴 CRITICAL"
             end

    puts "\nStatus: #{status}"
    puts "=" * 50

    # Return summary for potential chaining
    {
      score: metrics[:overall_score],
      status: metrics[:overall_score] >= 8 ? "healthy" : metrics[:overall_score] >= 6 ? "fair" : "needs_improvement"
    }
  end
end

