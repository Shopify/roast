# typed: true
# frozen_string_literal: true

#: self as Roast::Workflow

# This workflow demonstrates processing multiple targets with custom arguments.
# It accepts any number of files and optional arguments for controlling output.
#
# Run it with:
#   bin/roast execute tutorial/03_targets_and_params/multiple_targets.rb \
#     Gemfile Gemfile.lock
#
# Or try:
#   bin/roast execute tutorial/03_targets_and_params/multiple_targets.rb \
#     dsl/**/*.rb -- count format=detailed
#
# Or get a little crazy:
#   bin/roast execute tutorial/03_targets_and_params/multiple_targets.rb \
#     dsl/**/*.md -- format=json

config do
  cmd { display! }
end

execute do
  # Show what we're processing
  ruby do
    puts "Processing #{targets.length} file(s):\n  - #{targets.join("\n  - ")}\n"
    puts "Counting file lines" if arg?(:count)
    puts "Arguments: #{args.inspect}" if args.any?
    puts "Keyword arguments: #{kwargs.inspect}" if kwargs.any?
  end

  # Analyze each file
  chat(:analyze_files) do
    format = kwarg(:format) || "summary"
    <<~PROMPT
      Please analyze these files and provide an #{format} overview:

      #{targets.map { |f| "- #{f}" }.join("\n")}

      Based on the filenames, what can you infer about this project?
      What do you think these files are used for?

      #{format == "detailed" ? "Provide detailed insights for each file." : "Keep it brief (2-3 sentences)."}
    PROMPT
  end

  # Count total lines across all files
  cmd(:total_lines) do |my|
    my.stdin = targets.join("\n")
    "xargs wc -l | awk '/total$/{print $1}'"
  end

  # Display results
  ruby do
    puts "\n" + "=" * 60
    puts "ANALYSIS RESULTS"
    puts "=" * 60
    puts "Total lines: #{arg?(:count) ? cmd!(:total_lines).out : "---"}"
    puts "Format: #{kwarg(:format)}" if kwarg?(:format)
    puts chat!(:analyze_files).text
    puts "=" * 60
  end
end
