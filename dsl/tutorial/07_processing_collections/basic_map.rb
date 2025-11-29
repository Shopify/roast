# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

config do
  chat do
    model "gpt-4o-mini"
    provider :openai
    no_display!
  end
end

execute(:analyze_city) do
  chat(:extract_info) do |_, city|
    <<~PROMPT
      For the city #{city}, provide a one-sentence fact about its population or geography.
      Keep it brief and factual.
    PROMPT
  end
end

execute do
  cities = ["Tokyo", "Paris", "Cairo", "Sydney"]

  # Apply the :analyze_city scope to each city
  map(:city_analysis, run: :analyze_city) { cities }

  # Collect all the responses
  ruby do
    puts "\n=== City Facts ==="
    facts = collect(map!(:city_analysis)) do
      chat!(:extract_info).response.strip
    end

    cities.each_with_index do |city, i|
      puts "#{city}: #{facts[i]}"
    end
  end

  # Use reduce to combine results
  ruby do
    summary = reduce(map!(:city_analysis), "Summary of cities:") do |acc, _, city, index|
      "#{acc}\n- #{city} (position #{index})"
    end
    puts "\n#{summary}"
  end

  # Access a specific iteration
  ruby do
    puts "\n=== Accessing Specific Iterations ==="

    # Get the second city's analysis (Paris, index 1)
    paris_fact = from(map!(:city_analysis).iteration(1)) do
      chat!(:extract_info).response.strip
    end
    puts "Paris (index 1): #{paris_fact}"

    # Access first and last
    first_city = from(map!(:city_analysis).first) do
      chat!(:extract_info).response.strip
    end
    last_city = from(map!(:city_analysis).last) do
      chat!(:extract_info).response.strip
    end

    puts "First: #{first_city}"
    puts "Last: #{last_city}"
  end
end
