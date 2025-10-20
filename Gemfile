# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in roast.gemspec
gemspec

gem "cgi"
gem "claude_swarm"
# TODO: remove this version pin when the next cli-ui version is released with this circular dependency fix
#   https://github.com/Shopify/cli-ui/pull/606
gem "cli-ui", github: "Shopify/cli-ui", ref: "0185746bac2e34e7609e02a4d585c5f19703200e"
gem "dotenv"
gem "guard-minitest"
gem "guard"
gem "minitest-rg"
gem "mocha"
gem "rake", require: false
gem "rubocop-shopify", require: false
gem "rubocop-sorbet", require: false
gem "ruby_llm"
gem "simplecov", require: false
gem "sorbet", require: false
gem "tapioca", require: false
gem "vcr", require: false
gem "webmock", require: false
