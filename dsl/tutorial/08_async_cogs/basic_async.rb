# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  agent do
    async!
    display!
  end
end

execute do
  # All three agents start immediately and run in the background
  agent(:readme) do
    "Read the README.md file and give me a one-sentence summary of what this project does."
  end

  agent(:gemfile) do
    "Look at the Gemfile and list the 3 most important dependencies (just their names)."
  end

  agent(:structure) do
    "Look at the directory structure and tell me what programming language this project uses."
  end

  # When we access outputs, we block until that agent completes
  ruby do
    puts "=== Project Summary ==="
    puts agent!(:readme).response

    puts "=== Key Dependencies ==="
    puts agent!(:gemfile).response

    puts "=== Language ==="
    puts agent!(:structure).response
  end
end
