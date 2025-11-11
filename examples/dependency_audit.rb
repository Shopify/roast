# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Dependency Audit
#
# This workflow analyzes Ruby project dependencies for security vulnerabilities,
# outdated packages, and maintenance status. Demonstrates system command
# integration and dependency analysis patterns.
#
# Run with: bundle exec bin/roast execute examples/dependency_audit.rb --executor dsl

config do
  agent do
    provider :claude
    model "haiku"
  end
end

execute do
  # Step 1: Analyze current dependencies
  agent(:analyze_gemfile) do
    "Examine the Gemfile and Gemfile.lock to understand the project's dependencies. Look for the types of gems used, version constraints, and overall dependency strategy. Identify any obviously outdated or problematic dependencies."
  end

  # Step 2: Check for bundle audit capability and run if available
  ruby(:check_bundle_audit) do
    # Check if bundle-audit is available
    result = `which bundle-audit 2>/dev/null`
    audit_available = $?.success? && !result.strip.empty?

    if audit_available
      puts "Running bundle audit for security vulnerabilities..."
      audit_output = `bundle audit 2>&1`
      audit_success = $?.success?

      {
        audit_available: true,
        audit_output: audit_output,
        audit_success: audit_success,
        vulnerabilities_found: !audit_success
      }
    else
      puts "bundle-audit not available, skipping security scan"
      {
        audit_available: false,
        audit_output: "bundle-audit gem not installed",
        audit_success: false,
        vulnerabilities_found: false
      }
    end
  end

  # Step 3: Check for outdated dependencies
  ruby(:check_outdated) do
    puts "Checking for outdated gems..."
    outdated_output = `bundle outdated 2>&1`
    outdated_available = $?.success?

    # Parse the output for outdated gems
    outdated_gems = []
    if outdated_available && outdated_output.include?("outdated gems")
      # Simple parsing - look for gem lines
      outdated_output.split("\n").each do |line|
        if line.match(/^\s*\*\s+(\w+)/)
          outdated_gems << line.strip
        end
      end
    end

    {
      outdated_available: outdated_available,
      outdated_output: outdated_output,
      outdated_count: outdated_gems.size,
      outdated_gems: outdated_gems.first(5) # Limit to first 5 for brevity
    }
  end

  # Step 4: Analyze dependency health
  agent(:analyze_dependency_health) do
    audit_results = ruby!(:check_bundle_audit).value
    outdated_results = ruby!(:check_outdated).value
    gemfile_analysis = agent!(:analyze_gemfile).response

    security_status = if audit_results[:vulnerabilities_found]
                        "SECURITY ISSUES FOUND"
                      elsif audit_results[:audit_available]
                        "No known vulnerabilities"
                      else
                        "Security scan unavailable"
                      end

    outdated_status = case outdated_results[:outdated_count]
                      when 0 then "All dependencies up to date"
                      when 1..3 then "Few outdated dependencies"
                      when 4..10 then "Several outdated dependencies"
                      else "Many outdated dependencies"
                      end

    "Analyze the overall dependency health based on this information:\n\nSecurity Status: #{security_status}\nOutdated Status: #{outdated_status}\nOutdated Count: #{outdated_results[:outdated_count]}\n\nGemfile Analysis:\n#{gemfile_analysis}\n\nProvide recommendations for improving dependency management and security."
  end

  # Step 5: Generate final report
  ruby(:generate_report) do
    audit_results = ruby!(:check_bundle_audit).value
    outdated_results = ruby!(:check_outdated).value
    health_analysis = agent!(:analyze_dependency_health).response

    puts "\n" + "=" * 60
    puts "DEPENDENCY AUDIT REPORT"
    puts "=" * 60
    puts "Audit Date: #{Time.now.iso8601}"
    puts

    # Security section
    puts "🔒 SECURITY STATUS"
    puts "-" * 20
    if audit_results[:audit_available]
      if audit_results[:vulnerabilities_found]
        puts "❌ Security vulnerabilities detected!"
        puts "Run 'bundle audit' for details"
      else
        puts "✅ No known security vulnerabilities"
      end
    else
      puts "⚠️  Security audit unavailable (install bundle-audit gem)"
    end
    puts

    # Outdated dependencies section
    puts "📦 DEPENDENCY FRESHNESS"
    puts "-" * 25
    case outdated_results[:outdated_count]
    when 0
      puts "✅ All dependencies are up to date"
    when 1..3
      puts "🟡 #{outdated_results[:outdated_count]} outdated dependencies (minor)"
    when 4..10
      puts "🟠 #{outdated_results[:outdated_count]} outdated dependencies (moderate)"
    else
      puts "🔴 #{outdated_results[:outdated_count]} outdated dependencies (significant)"
    end

    unless outdated_results[:outdated_gems].empty?
      puts "\nSample outdated gems:"
      outdated_results[:outdated_gems].each { |gem| puts "  #{gem}" }
    end
    puts

    # Recommendations section
    puts "💡 RECOMMENDATIONS"
    puts "-" * 18
    puts health_analysis
    puts
    puts "=" * 60

    # Return summary
    {
      security_clean: !audit_results[:vulnerabilities_found],
      outdated_count: outdated_results[:outdated_count],
      overall_health: outdated_results[:outdated_count] == 0 && !audit_results[:vulnerabilities_found] ? "excellent" : "needs_attention"
    }
  end
end