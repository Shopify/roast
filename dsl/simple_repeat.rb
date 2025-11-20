# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
end

execute do
  repeat(:loop, run: :loop_body) {}
end

execute(:loop_body) do
  ruby(:one) do |_, _, idx|
    s = "iteration #{idx}"
    puts s
    s
  end

  ruby { |_, _, idx| break! if idx >= 3 }

  outputs { |_, idx| "output of iteration #{idx}" }
end
