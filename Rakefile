# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "rake/testtask"

### Test Tasks

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

Rake::TestTask.new(:minitest_dsl_fast) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/dsl/**/*_test.rb", "test/roast/dsl/**/*_test.rb"]
end

Rake::TestTask.new(:minitest_dsl_slow) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/dsl/**/*_test.rb", "test/roast/dsl/**/*_test.rb"]
end
task :set_slow_env do
  ENV["ROAST_RUN_SLOW_TESTS"] = "true"
end
task minitest_dsl_slow: :set_slow_env

task test: [:minitest_dsl_fast, :minitest_dsl_slow, :minitest_functional, :minitest_old]

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

task default: [:sorbet, :rubocop, :minitest_dsl_fast]

task check: [:sorbet, :rubocop]
