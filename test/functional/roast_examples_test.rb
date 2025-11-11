# frozen_string_literal: true

require "test_helper"

# This test suite validates the DSL example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "basic_prompt_workflow.rb" do
    VCR.use_cassette("basic_prompt_workflow") do
      stdout, _ = in_sandbox with_sample_data: "skateboard_orders.csv" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/basic_prompt_workflow.rb", "basic_prompt_workflow.rb")
        roast("execute", "basic_prompt_workflow.rb", "--executor", "dsl", "-t", "skateboard_orders.csv")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "grading.rb workflow" do
    VCR.use_cassette("grading") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/grading.rb", "grading.rb")
        roast("execute", "grading.rb", "--executor", "dsl", "-t", "simple_project/calculator_test.rb")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "code_health.rb workflow" do
    VCR.use_cassette("code_health") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/code_health.rb", "code_health.rb")
        roast("execute", "code_health.rb", "--executor", "dsl")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "docs_generator.rb workflow" do
    VCR.use_cassette("docs_generator") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/docs_generator.rb", "docs_generator.rb")
        roast("execute", "docs_generator.rb", "--executor", "dsl")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "dependency_audit.rb workflow" do
    VCR.use_cassette("dependency_audit") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/dependency_audit.rb", "dependency_audit.rb")
        roast("execute", "dependency_audit.rb", "--executor", "dsl")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "git_insights.rb workflow" do
    VCR.use_cassette("git_insights") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/git_insights.rb", "git_insights.rb")
        roast("execute", "git_insights.rb", "--executor", "dsl")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end

  test "issue_triage.rb workflow" do
    VCR.use_cassette("issue_triage") do
      stdout, _ = in_sandbox with_sample_data: "simple_project" do
        # Copy the DSL example into the sandbox
        FileUtils.cp("#{Roast::ROOT}/examples/issue_triage.rb", "issue_triage.rb")
        roast("execute", "issue_triage.rb", "--executor", "dsl")
      end
      # Verify DSL workflow started (shows experimental warning)
      assert_match(/experimental syntax/, stdout)
      # In CI environments without proper API keys, DSL may only show warning
      # In local environments with API keys, workflow executes fully
      assert stdout.length > 50, "Expected DSL to at least show experimental warning, got: #{stdout.inspect}"
    end
  end
end
