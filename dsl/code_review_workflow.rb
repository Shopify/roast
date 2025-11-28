# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Advanced Code Review Orchestration
#
# This workflow demonstrates complex orchestration combining both agent and chat
# capabilities. It shows realistic patterns of mixing structured analysis (agent)
# with conversational insights (chat) for comprehensive code review.
#
# Workflow: Agent analyzes structure -> Chat discusses findings -> Agent validates fixes -> Chat summarizes

config do
  # Agent for structured analysis and tool use
  agent do
    provider :claude
    model "haiku"
    initial_prompt "You are a senior code reviewer focused on Ruby best practices, security, and maintainability."
    show_stats!
    show_prompt!
  end

  # Chat for conversational analysis and insights
  chat(:reviewer) do
    model("gpt-4o-mini")
    assume_model_exists!
  end
end

execute do
  # Step 1: Agent performs structural analysis with tools
  agent(:structure_analysis) do
    "Analyze this Ruby project's structure. Check the directory layout, identify key architectural patterns, and look for any obvious structural issues. Focus on file organization, dependency patterns, and overall project health."
  end

  # Step 2: Chat provides conversational insights on the structural findings
  chat(:structure_discussion) do
    template("structure_insights", {
      agent_analysis: agent!(:structure_analysis).response,
    })
  end

  # Step 3: Agent performs detailed code quality analysis
  agent(:code_quality) do
    template("code_quality_analysis", {
      structure_insights: chat!(:structure_discussion).response,
    })
  end

  # Step 4: Chat analyzes patterns and suggests improvements
  chat(:improvement_suggestions) do
    template("improvement_analysis", {
      structure_analysis: agent!(:structure_analysis).response,
      code_quality: agent!(:code_quality).response,
    })
  end

  # Step 5: Agent validates the suggested improvements
  agent(:validation) do
    template("validate_suggestions", {
      suggestions: chat!(:improvement_suggestions).response,
    })
  end

  # Step 6: Chat creates executive summary
  chat(:executive_summary) do
    "Based on all the analysis above, create a comprehensive executive summary for the development team. Include: 1) Overall project health score, 2) Top 3 priority improvements, 3) Estimated effort for fixes, 4) Risk assessment if issues aren't addressed."
  end
end
