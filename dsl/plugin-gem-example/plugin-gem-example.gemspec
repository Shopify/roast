# frozen_string_literal: true

require_relative "lib/version"

Gem::Specification.new do |spec|
  spec.name = "plugin-gem-example"
  spec.version = Plugin::Gem::Example::VERSION
  spec.authors = ["Sam Schmidt"]
  spec.email = ["sam.schmidt@shopify.com"]

  spec.summary = "TODO: Write a short summary, because RubyGems requires one."
  spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Uncomment to register a new dependency of your gem
  spec.add_dependency("roast-ai")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
