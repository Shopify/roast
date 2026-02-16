# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in roast-ai.gemspec
gemspec

group :development, :test do
  gem "guard-minitest"
  gem "guard"
  gem "minitest", "~> 5.0"
  gem "minitest-rg"
  gem "mocha"
  gem "rake", require: false
  gem "rubocop-shopify", require: false
  gem "rubocop-sorbet", require: false
  gem "simplecov", require: false
  gem "sorbet", "~> 0.5.12414", require: false
  gem "sqlite3", require: false
  gem "tapioca", "~> 0.16.11", require: false
  gem "vcr", require: false
  gem "webmock", require: false
end
