# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

use "cool_agent", from: "plugin_gem_example"

config do
  agent do
    provider :cool_agent
    show_prompt!
  end
end

execute do
  agent { "What is the world's largest lake?" }
end
