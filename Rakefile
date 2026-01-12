# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "rake/testtask"

### Test Tasks

Rake::TestTask.new(:minitest_fast) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

Rake::TestTask.new(:minitest_all) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end
task :set_slow_test_env do
  ENV["ROAST_RUN_SLOW_TESTS"] = "true"
end
task minitest_all: :set_slow_test_env

### Rubocop Tasks

RuboCop::RakeTask.new(:rubocop_ci)

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ["--autocorrect"]
end

### Sorbet Tasks

desc "Run Sorbet type checker"
task :sorbet do
  sh "bin/srb tc" do |ok, _|
    abort "Sorbet type checking failed" unless ok
  end
end

### Task Groups

task default: [:sorbet, :rubocop, :minitest_fast]

task check: [:sorbet, :rubocop]

task test: [:minitest_all]
