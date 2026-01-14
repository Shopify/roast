# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
  cmd { display! }
  cmd(/to_/) { no_display! }
end

execute(:subroutine1) do
  ruby(:one) { "one" }
  ruby(:two) { skip! }
  # Attempting to access the output of a cog that did not run will not raise an exception inside the `outputs` block
  # Instead, it will just return `nil`
  outputs { ruby!(:two).value }
end

execute(:subroutine2) do
  ruby(:one) { "one" }
  ruby(:two) { skip! }
  # Attempting to access the output of a cog that did not run *will* raise an exception inside the `outputs!` block
  outputs! do
    puts "❗️ This block is expected to raise an exception ❗️"
    ruby!(:two).value
  end
end

execute do
  call(:one, run: :subroutine1) {}

  ruby { puts "Using the `outputs` block should return `nil`: #{from(call!(:one)) || "nil"}" }

  # The `outputs!` block in subroutine2 will raise an exception as soon as it is evaluated
  call(:two, run: :subroutine2) {}
end
