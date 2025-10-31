# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
end

execute do
  ruby do |_, params|
    # Any files listed after the standard roast command-line args are collected as your workflows targets
    # (shell globs are expanded as you would expect)
    # e.g., `roast execute --executor=dsl dsl/targets_and_params.rb Gemfile Gemfile.lock`
    # or, `roast execute --executor=dsl dsl/targets_and_params.rb Gemfile*`
    puts "workflow targets: #{params.targets}"

    # You can specify custom arguments for your workflow. Anything coming after `--` on the roast command
    # line will be parsed as custom arguments.
    # Simple word tokens are collected as `args`. Tokens in the form `key=value` are parsed into the `kwargs` hash.
    # e.g., `roast execute --executor=dsl dsl/targets_and_params.rb Gemfile* -- foo=bar abc=pqr hello world`
    puts "workflow args: #{params.args}" # [:hello, :world] (args are parsed as symbols)
    puts "workflow kwargs: #{params.kwargs}" # {abc: "pqr", foo: "bar"} (keys are parsed as symbols, values as strings)
  end
end
