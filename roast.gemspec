# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "roast/version"

Gem::Specification.new do |spec|
  spec.name          = "roast-ai"
  spec.version       = Roast::VERSION
  spec.authors       = ["Shopify"]
  spec.email         = ["opensource@shopify.com"]

  spec.summary       = "A framework for executing structured AI workflows in Ruby"
  spec.description   = "Roast is a Ruby library for running structured AI workflows along with many building blocks for creating and executing them"
  spec.homepage      = "https://github.com/Shopify/roast"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/Shopify/roast"
    spec.metadata["changelog_uri"] = "https://github.com/Shopify/roast/blob/main/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    %x(git ls-files -z).split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) || f.end_with?(".gem") }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("activesupport", ">= 7.0")
  spec.add_dependency("async", "~> 2.34")
  spec.add_dependency("cli-kit", "~> 5.2")
  spec.add_dependency("cli-ui", "~> 2.6")
  spec.add_dependency("diff-lcs", "~> 1.5")
  spec.add_dependency("json-schema")
  spec.add_dependency("open_router", "~> 0.3")
  spec.add_dependency("raix", "~> 1.0.2")
  spec.add_dependency("ruby_llm")
  spec.add_dependency("sqlite3", "~> 2.6")
  spec.add_dependency("thor", "~> 1.3")
  spec.add_dependency("zeitwerk", "~> 2.6")
end
