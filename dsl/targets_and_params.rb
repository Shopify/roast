# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

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

    # {abc: "pqr", foo: "bar"} (keys are parsed as symbols, values as strings)
    puts "workflow kwargs: #{params.kwargs}"
  end

  # There are convenience methods to access the workflow params from any cog input context in any scope
  ruby do
    puts
    # `target!` will raise an exception unless exactly one target is provided
    # puts "Explicit target = #{target!}"

    # `targets` will return the (possibly empty) array of targets
    puts "All targets = #{targets}"

    # `arg?` will return a boolean indicating whether a specific value / flag argument is present
    puts "Argument 'foo' provided? #{arg?(:foo) ? "yes" : "no"}"

    # `args` will return the (possibly empty) array of simple value / flag arguments
    puts "All args = #{args}"

    # `kwarg` will return the value associated with a specific keyword argument,
    # or nil if that keyword argument was not provided
    puts "Keyword argument 'name': '#{kwarg(:name)}'"

    # `kwarg!` will return the value associated with a specific keyword argument,
    # or raise an exception if that keyword argument was not provided
    # puts "Keyword argument 'name': #{kwarg!(:name)}"

    # `kwarg?` will return a boolean indicating whether a specific keyword argument was provided
    puts "Keyword argument 'name' provided: #{kwarg?(:name) ? "yes" : "no"}"

    # `kwargs` will return the (possibly empty) hash of all keyword arguments
    # puts "All kwargs = #{kwargs}"
  end
end
