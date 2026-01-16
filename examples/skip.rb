# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd { display! }
end

execute do
  cmd(:seconds) { "date +'%S'" }

  cmd(:even) do
    # `cmd!` output accessor bang method will raise an exception if the named cog did not complete successfully
    seconds = cmd!(:seconds).out.to_i
    # Use the `skip!` method in a cog's input proc to conditionally skip this cog
    # If `skip!` is called, the input proc will immediately terminate
    skip! if seconds.odd?
    "echo '#{seconds} is even'"
  end

  cmd(:odd) do
    seconds = cmd!(:seconds).out.to_i
    skip! if seconds.even?
    "echo '#{seconds} is odd'"
  end

  cmd do |my|
    my.command = "echo"
    # `cmd` output accessor non-bang method will return the cog's output or
    # nil if the named cog did not run yet or did not complete successfully
    my.args << "'even' cog ran" unless cmd(:even).nil?
    # `cmd?` output accessor question method will return true/false if the cog did / did not complete successfully yet
    my.args << "'odd' cog ran" if cmd?(:odd)
  end
end
