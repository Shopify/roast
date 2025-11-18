# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
end

execute do
  # You can use `repeat` to repeat an executor multiple times
  # The executor will run forever until it breaks according to its internal logic
  repeat(:loop, run: :loop_body) {}
end

execute(:loop_body) do
  ruby(:one) do |_, _, idx|
    s = "iteration #{idx}"
    puts s
    s
  end

  # Use `break!` to terminate the repeat loop
  # Cogs that occur after `break!` is called will not run on the final iteration
  ruby { |_, _, idx| break! if idx >= 3 }

  # The `outputs` block will *always* run, including on the iteration in which the `break!` was issued
  # NOTE: Be careful not to depend on the output of cogs that only run after the break point
  outputs { |_, idx| "output of iteration #{idx}" }
end
