# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Issue Triage Helper
#
# This workflow analyzes GitHub issues and helps categorize, prioritize,
# and provide initial responses. Demonstrates API integration patterns
# and text analysis workflows. Requires GitHub CLI (`gh`) to be installed.
#
# Run with: bundle exec bin/roast execute examples/issue_triage.rb --executor dsl

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Check GitHub CLI availability and get recent issues
  ruby(:fetch_recent_issues) do
    # Check if gh CLI is available
    unless system("which gh > /dev/null 2>&1")
      puts "❌ GitHub CLI (gh) not found. Install it from https://cli.github.com/"
      return { error: "GitHub CLI not available" }
    end

    # Check if authenticated
    auth_check = `gh auth status 2>&1`
    unless $?.success?
      puts "❌ Not authenticated with GitHub. Run 'gh auth login'"
      return { error: "GitHub authentication required" }
    end

    puts "Fetching recent issues..."

    # Get recent issues (last 10 open issues)
    issues_json = `gh issue list --limit 10 --json number,title,body,labels,createdAt,author --state open 2>/dev/null`

    if $?.success? && !issues_json.empty?
      begin
        issues = JSON.parse(issues_json)
        puts "Found #{issues.size} recent issues to analyze"
        { issues: issues, count: issues.size }
      rescue JSON::ParserError
        puts "⚠️  Could not parse issues JSON"
        { issues: [], count: 0 }
      end
    else
      puts "⚠️  No issues found or unable to fetch issues"
      { issues: [], count: 0 }
    end
  end

  # Step 2: Analyze issues for common patterns and categorization
  agent(:analyze_issues) do
    issue_data = ruby!(:fetch_recent_issues).value

    if issue_data[:error]
      return "Unable to analyze issues: #{issue_data[:error]}"
    end

    if issue_data[:count] == 0
      return "No issues to analyze. This could mean the repository has no open issues (great!), or there might be access limitations."
    end

    # Format issues for analysis
    issues_summary = issue_data[:issues].first(5).map do |issue|
      labels = issue['labels'].map { |l| l['name'] }.join(", ") if issue['labels']
      "Issue ##{issue['number']}: #{issue['title']}\nLabels: #{labels || 'none'}\nAuthor: #{issue['author']['login']}\nPreview: #{(issue['body'] || '').strip[0..200]}..."
    end.join("\n\n")

    "Analyze these GitHub issues and provide:\n1. Common patterns or themes\n2. Suggested categorization (bug, feature, documentation, etc.)\n3. Priority assessment (high, medium, low)\n4. Any issues that might be duplicates or related\n\nIssues to analyze:\n#{issues_summary}"
  end

  # Step 3: Generate triage recommendations
  ruby(:generate_triage_recommendations) do
    issue_data = ruby!(:fetch_recent_issues).value
    analysis = agent!(:analyze_issues).response

    if issue_data[:error] || issue_data[:count] == 0
      return {
        recommendations: [],
        summary: analysis,
        actionable_count: 0
      }
    end

    # Simple categorization based on keywords in titles/bodies
    recommendations = issue_data[:issues].map do |issue|
      title_lower = issue['title'].downcase
      body_lower = (issue['body'] || '').downcase

      # Simple keyword-based categorization
      category = if title_lower.include?('bug') || title_lower.include?('error') || title_lower.include?('broken')
                   'bug'
                 elsif title_lower.include?('feature') || title_lower.include?('enhancement') || title_lower.include?('add')
                   'enhancement'
                 elsif title_lower.include?('doc') || title_lower.include?('readme') || title_lower.include?('documentation')
                   'documentation'
                 elsif title_lower.include?('question') || title_lower.include?('help')
                   'question'
                 else
                   'uncategorized'
                 end

      # Simple priority based on keywords
      priority = if title_lower.include?('urgent') || title_lower.include?('critical') || body_lower.include?('production')
                   'high'
                 elsif title_lower.include?('nice to have') || title_lower.include?('minor')
                   'low'
                 else
                   'medium'
                 end

      {
        number: issue['number'],
        title: issue['title'],
        suggested_category: category,
        suggested_priority: priority,
        author: issue['author']['login'],
        created_at: issue['createdAt']
      }
    end

    {
      recommendations: recommendations,
      summary: analysis,
      actionable_count: recommendations.size
    }
  end

  # Step 4: Display triage report
  ruby(:display_triage_report) do
    issue_data = ruby!(:fetch_recent_issues).value
    triage_data = ruby!(:generate_triage_recommendations).value

    puts "\n" + "=" * 60
    puts "ISSUE TRIAGE REPORT"
    puts "=" * 60
    puts "Analysis Date: #{Time.now.iso8601}"
    puts

    if issue_data[:error]
      puts "❌ #{issue_data[:error]}"
      puts "\nTo use this workflow:"
      puts "1. Install GitHub CLI: https://cli.github.com/"
      puts "2. Run: gh auth login"
      puts "3. Navigate to a repository with GitHub issues"
      return { error: issue_data[:error] }
    end

    if issue_data[:count] == 0
      puts "✅ No open issues found!"
      puts "This could mean:"
      puts "• Repository has no open issues (excellent!)"
      puts "• Repository is private and you lack access"
      puts "• GitHub API rate limit reached"
      return { status: "no_issues" }
    end

    puts "📊 ISSUE SUMMARY"
    puts "-" * 16
    puts "Total issues analyzed: #{triage_data[:actionable_count]}"

    # Category breakdown
    categories = triage_data[:recommendations].group_by { |r| r[:suggested_category] }
    categories.each do |category, issues|
      emoji = case category
              when 'bug' then '🐛'
              when 'enhancement' then '✨'
              when 'documentation' then '📚'
              when 'question' then '❓'
              else '📋'
              end
      puts "#{emoji} #{category.capitalize}: #{issues.size}"
    end
    puts

    # Priority breakdown
    puts "🎯 PRIORITY BREAKDOWN"
    puts "-" * 20
    priorities = triage_data[:recommendations].group_by { |r| r[:suggested_priority] }
    priorities.each do |priority, issues|
      emoji = case priority
              when 'high' then '🔴'
              when 'medium' then '🟡'
              when 'low' then '🟢'
              else '⚪'
              end
      puts "#{emoji} #{priority.capitalize}: #{issues.size}"
    end
    puts

    # Specific recommendations
    puts "📝 TRIAGE RECOMMENDATIONS"
    puts "-" * 26
    triage_data[:recommendations].first(5).each do |rec|
      priority_emoji = case rec[:suggested_priority]
                       when 'high' then '🔴'
                       when 'medium' then '🟡'
                       else '🟢'
                       end

      puts "#{priority_emoji} Issue ##{rec[:number]} - #{rec[:suggested_category].upcase}"
      puts "   Title: #{rec[:title]}"
      puts "   Author: #{rec[:author]}"
      puts
    end

    # AI Analysis Summary
    puts "🤖 PATTERN ANALYSIS"
    puts "-" * 18
    puts triage_data[:summary]
    puts
    puts "=" * 60

    {
      total_issues: triage_data[:actionable_count],
      categories: categories.keys,
      high_priority_count: priorities['high']&.size || 0
    }
  end
end