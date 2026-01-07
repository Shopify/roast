# typed: false
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Test workflow for VCR infrastructure
# Used by test/dsl/functional/roast_dsl_examples_test.rb

config do
  chat(:test) { model("gpt-4o") }
end

execute do
  chat(:test) { "What is the deepest lake?" }
end
