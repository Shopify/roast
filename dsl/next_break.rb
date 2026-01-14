# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

config do
end

execute do
  map(:loop, run: :loop_body) { 1..3 }

  ruby do
    results = collect(map!(:loop)) do
      [ruby?(:one), ruby?(:two), ruby?(:three)]
    end
    results.each_with_index do |iteration_results, index|
      puts "Iteration #{index}: #{iteration_results.presence || "did not run at all"}"
    end
  end

  call(:once, run: :loop_body) do |my|
    my.value = 1
    my.index = 1
  end
end

execute(:loop_body) do
  ruby(:one) do |_, _, idx|
    skip! if idx == 0
    s = "[#{idx}] beginning"
    puts s
    s
  end
  ruby(:two) do |_, _, idx|
    break! if idx == 1
    s = "[#{idx}] middle"
    puts s
    s
  end
  ruby(:three) do |_, _, idx|
    s = "[#{idx}] end"
    puts s
    s
  end
end
