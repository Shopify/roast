# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# This tutorial demonstrates template shortcuts in Roast DSL workflows.
# Template shortcuts allow you to reference templates by name without specifying full paths.
# The system searches for templates in these locations (in order):
#   1. Exact path (if absolute)
#   2. workflow_dir/prompts/name.md.erb
#   3. workflow_dir/prompts/name.erb
#   4. workflow_dir/name.md.erb
#   5. workflow_dir/name.erb
#   6. current_dir/prompts/name.md.erb
#   7. current_dir/prompts/name.erb
#   8. current_dir/name.md.erb
#   9. current_dir/name.erb
#   10-13. Same patterns with relative path resolution

config do
  agent do
    provider :claude
    model "haiku"
    show_prompt!
  end
end

execute do
  # Example 1: Basic template shorthand
  # This will find prompts/greeting.md.erb automatically
  agent(:welcome) do
    template("greeting", {
      name: "Developer",
      role: "Tutorial Student",
      topic: "Template Shortcuts",
    })
  end

  # Example 2: Multiple templates with different extensions
  # This will find prompts/analysis_request.erb (note: .erb has higher priority than .md.erb)
  agent(:analyzer) do
    template("analysis_request", {
      content_type: "code snippet",
      content: "def hello\n  puts 'Hello, World!'\nend",
      focus_areas: ["syntax", "style", "functionality"],
    })
  end

  # Example 3: Comparing shorthand vs full path
  # Both of these do the same thing:

  # Full path (the old way)
  agent(:full_path_example) do
    template("prompts/greeting.md.erb", {
      name: "Full Path User",
      topic: "Explicit Template Paths",
    })
  end

  # Shorthand (the new way - cleaner and more maintainable)
  agent(:shorthand_example) do
    template("greeting", {
      name: "Shorthand User",
      topic: "Template Shortcuts",
    })
  end

  # Example 4: Template reuse with different variables
  agent(:reuse_demo) do
    template("greeting", {
      name: "Roast User",
      role: "Workflow Designer",
      topic: "Template Reusability",
    })
  end
end
