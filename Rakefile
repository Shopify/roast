# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "rake/testtask"

Rake::TestTask.new(:minitest_all) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

Rake::TestTask.new(:minitest_functional) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/functional/**/*_test.rb"]
end

task test: [:minitest_all]

RuboCop::RakeTask.new(:rubocop_ci)

task ci: [:test, :rubocop_ci]

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ["--autocorrect"]
end

task default: [:test, :rubocop]
