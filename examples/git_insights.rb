# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Git Repository Insights
#
# This workflow analyzes git repository history to provide insights about
# development patterns, contributor activity, and code evolution.
# Demonstrates git command integration and data analysis patterns.
#
# Run with: bundle exec bin/roast execute examples/git_insights.rb --executor dsl

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Basic repository information
  ruby(:gather_basic_info) do
    # Check if we're in a git repository
    unless system("git rev-parse --git-dir > /dev/null 2>&1")
      puts "❌ Not a git repository"
      return { error: "Not in a git repository" }
    end

    # Gather basic repo info
    repo_info = {
      total_commits: `git rev-list --all --count`.strip.to_i,
      current_branch: `git branch --show-current`.strip,
      remote_url: `git config --get remote.origin.url`.strip,
      last_commit_date: `git log -1 --format="%ci"`.strip
    }

    puts "Repository Analysis Starting..."
    puts "Total commits: #{repo_info[:total_commits]}"
    puts "Current branch: #{repo_info[:current_branch]}"
    puts "Last commit: #{repo_info[:last_commit_date]}"

    repo_info
  end

  # Step 2: Analyze recent activity (last 30 days)
  ruby(:analyze_recent_activity) do
    basic_info = ruby!(:gather_basic_info).value
    return { error: basic_info[:error] } if basic_info[:error]

    # Get commits from last 30 days
    recent_commits_output = `git log --since="30 days ago" --oneline 2>/dev/null`
    recent_commits = recent_commits_output.split("\n")

    # Get contributor activity
    contributors_output = `git shortlog --since="30 days ago" -sn 2>/dev/null`
    contributors = contributors_output.split("\n").map do |line|
      parts = line.strip.split("\t")
      { commits: parts[0].to_i, author: parts[1] } if parts.size == 2
    end.compact.first(10)

    # Get most changed files
    changed_files_output = `git log --since="30 days ago" --name-only --pretty=format: 2>/dev/null`
    file_changes = Hash.new(0)
    changed_files_output.split("\n").reject(&:empty?).each { |file| file_changes[file] += 1 }
    most_changed = file_changes.sort_by { |_, count| -count }.first(10)

    {
      recent_commit_count: recent_commits.size,
      recent_commits_sample: recent_commits.first(5),
      active_contributors: contributors,
      most_changed_files: most_changed.map { |file, count| { file: file, changes: count } }
    }
  end

  # Step 3: Analyze repository patterns
  agent(:analyze_patterns) do
    basic_info = ruby!(:gather_basic_info).value
    recent_activity = ruby!(:analyze_recent_activity).value

    return "Unable to analyze patterns - repository data unavailable" if basic_info[:error]

    summary = []
    summary << "Repository has #{basic_info[:total_commits]} total commits"
    summary << "#{recent_activity[:recent_commit_count]} commits in the last 30 days"
    summary << "#{recent_activity[:active_contributors].size} active contributors recently"

    if recent_activity[:most_changed_files].any?
      top_file = recent_activity[:most_changed_files].first
      summary << "Most changed file: #{top_file[:file]} (#{top_file[:changes]} changes)"
    end

    "Analyze these git repository patterns and provide insights about development activity, code evolution, and team collaboration patterns:\n\n#{summary.join("\n")}\n\nActive contributors: #{recent_activity[:active_contributors].map { |c| "#{c[:author]} (#{c[:commits]} commits)" }.join(", ")}\n\nRecent commit examples: #{recent_activity[:recent_commits_sample].join("; ")}"
  end

  # Step 4: Generate repository health assessment
  ruby(:assess_repository_health) do
    basic_info = ruby!(:gather_basic_info).value
    recent_activity = ruby!(:analyze_recent_activity).value
    pattern_analysis = agent!(:analyze_patterns).response

    return { error: basic_info[:error] } if basic_info[:error]

    # Simple health scoring
    health_score = 10

    # Deduct points for inactivity
    if recent_activity[:recent_commit_count] == 0
      health_score -= 4
    elsif recent_activity[:recent_commit_count] < 5
      health_score -= 2
    end

    # Deduct points for low contributor diversity
    contributor_count = recent_activity[:active_contributors].size
    if contributor_count <= 1
      health_score -= 2
    end

    # Assess based on commit frequency
    days_since_last_commit = if basic_info[:last_commit_date].empty?
                               999
                             else
                               (Time.now - Time.parse(basic_info[:last_commit_date])) / (24 * 3600)
                             end

    if days_since_last_commit > 30
      health_score -= 3
    elsif days_since_last_commit > 7
      health_score -= 1
    end

    health_score = [health_score, 1].max # Minimum score of 1

    {
      health_score: health_score,
      total_commits: basic_info[:total_commits],
      recent_activity: recent_activity[:recent_commit_count],
      contributor_diversity: contributor_count,
      days_since_last_commit: days_since_last_commit.round,
      assessment_date: Time.now.iso8601
    }
  end

  # Step 5: Display comprehensive report
  ruby(:display_report) do
    basic_info = ruby!(:gather_basic_info).value
    recent_activity = ruby!(:analyze_recent_activity).value
    health_assessment = ruby!(:assess_repository_health).value
    pattern_analysis = agent!(:analyze_patterns).response

    if basic_info[:error]
      puts "\n❌ Unable to analyze repository: #{basic_info[:error]}"
      return { error: basic_info[:error] }
    end

    puts "\n" + "=" * 60
    puts "GIT REPOSITORY INSIGHTS REPORT"
    puts "=" * 60
    puts "Analysis Date: #{health_assessment[:assessment_date]}"
    puts "Repository Branch: #{basic_info[:current_branch]}"
    puts

    # Health Score Section
    score = health_assessment[:health_score]
    status = case score
             when 8..10 then "🟢 EXCELLENT"
             when 6..7 then "🟡 GOOD"
             when 4..5 then "🟠 FAIR"
             else "🔴 NEEDS ATTENTION"
             end

    puts "📊 REPOSITORY HEALTH SCORE: #{score}/10 #{status}"
    puts

    # Activity Section
    puts "📈 DEVELOPMENT ACTIVITY"
    puts "-" * 25
    puts "Total commits: #{health_assessment[:total_commits]}"
    puts "Recent commits (30 days): #{health_assessment[:recent_activity]}"
    puts "Active contributors: #{health_assessment[:contributor_diversity]}"
    puts "Days since last commit: #{health_assessment[:days_since_last_commit]}"
    puts

    # Top Contributors
    if recent_activity[:active_contributors].any?
      puts "👥 TOP CONTRIBUTORS (30 days)"
      puts "-" * 30
      recent_activity[:active_contributors].first(5).each_with_index do |contributor, index|
        puts "#{index + 1}. #{contributor[:author]} (#{contributor[:commits]} commits)"
      end
      puts
    end

    # Most Changed Files
    if recent_activity[:most_changed_files].any?
      puts "📁 MOST ACTIVE FILES (30 days)"
      puts "-" * 28
      recent_activity[:most_changed_files].first(5).each_with_index do |file_info, index|
        puts "#{index + 1}. #{file_info[:file]} (#{file_info[:changes]} changes)"
      end
      puts
    end

    # AI Analysis
    puts "🤖 PATTERN ANALYSIS"
    puts "-" * 19
    puts pattern_analysis
    puts
    puts "=" * 60

    {
      health_score: score,
      total_commits: health_assessment[:total_commits],
      recent_activity_level: health_assessment[:recent_activity] > 10 ? "high" : health_assessment[:recent_activity] > 3 ? "moderate" : "low"
    }
  end
end