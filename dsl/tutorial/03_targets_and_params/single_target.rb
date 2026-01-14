# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates using target! to process a single URL.
# It expects exactly one URL to be provided on the command line.
#
# Run it with:
#   bin/roast execute --executor=dsl dsl/tutorial/03_targets_and_params/single_target.rb \
#     https://example.com
#
# Try running it with no URLs or multiple URLs to see how target! validates input.

config do
  chat { no_show_response! }
end

execute do
  # Fetch the target URL
  cmd(:fetch_url) do
    "curl -sL #{target!}"
  end

  # Count words and lines in the content
  cmd(:count_words) do
    content = cmd!(:fetch_url).out
    "echo #{content.shellescape} | wc -w"
  end

  cmd(:count_lines) do |my|
    content = cmd!(:fetch_url).out
    my.stdin = content
    "wc -l"
  end

  # Analyze the content with an LLM
  chat(:analyze) do
    content = cmd!(:fetch_url).out
    <<~PROMPT
      Please analyze this web page content and provide a brief summary (2-3 sentences):

      URL: #{target!}

      Content:
      #{content}

      Focus on what the page contains and its purpose.
    PROMPT
  end

  # Display the results
  ruby do
    puts "\n" + "=" * 60
    puts "WEB PAGE ANALYSIS"
    puts "=" * 60
    puts "URL: #{target!}"
    puts "Words: #{cmd!(:count_words).out.strip}"
    puts "Lines: #{cmd!(:count_lines).out.strip}"
    puts
    puts "Summary:"
    puts chat!(:analyze).response
    puts "=" * 60
  end
end
