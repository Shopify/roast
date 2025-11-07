# typed: true
# frozen_string_literal: true

#: self as Roast::DSL::Workflow

# Test Grading - Comprehensive evaluation of test file quality
# This workflow analyzes test files for quality, maintainability, and effectiveness

config do
  agent do
    provider :claude
    model "haiku"
  end

  # Special configurations for steps that need more powerful model
  agent(:generate_grades) do
    provider :claude
    model "sonnet"
  end

  agent(:generate_recommendations) do
    provider :claude
    model "sonnet"
  end
end

execute do
  # Step 1: Read dependencies and understand the subject under test
  agent(:read_dependencies) do |_, params|
    file_param = params.targets.first || "test file not provided"
    template("dependency_analysis", target_file: file_param)
  end

  # Steps 2 & 3: Run verification checks in parallel
  map(:verification_checks, run: :verify_aspect) { ["test_helpers", "mocks_and_stubs"] }

  # Step 4: Generate detailed grades with JSON output
  agent(:generate_grades) { template("test_grading_rubric") }

  # Step 5: Calculate final grade based on the detailed grades
  ruby(:calculate_final_grade) do
    grades_json = agent!(:generate_grades).response

    # Extract JSON from the response
    json_match = grades_json.match(/<json>(.*?)<\/json>/m)
    return { error: "Could not parse grades JSON" } unless json_match

    json_content = json_match[1]
    return { error: "Empty JSON content" } if json_content.nil? || json_content.empty?

    grades = JSON.parse(json_content)
    scores = grades.values.map { |rubric| rubric["score"] }
    final_score = scores.sum / scores.size.to_f

    letter_grade = case final_score
                   when 9..10 then "A+"
                   when 8...9 then "A"
                   when 7...8 then "B+"
                   when 6...7 then "B"
                   when 5...6 then "C+"
                   when 4...5 then "C"
                   when 3...4 then "D+"
                   when 2...3 then "D"
                   else "F"
                   end

    { final_score: final_score.round(1), letter_grade: letter_grade, individual_scores: grades }
  end

  # Step 6: Format the result for display
  ruby(:format_result) do |_, params|
    file_param = params.targets.first || "test file"
    final_grade = ruby!(:calculate_final_grade).value

    if final_grade[:error]
      puts final_grade[:error]
    else
      puts "=" * 40
      puts "TEST GRADE REPORT"
      puts "=" * 40
      puts "Test file: #{file_param}"
      puts ""
      puts "FINAL GRADE:"
      puts "  Score: #{final_grade[:final_score]}/10"
      puts "  Letter Grade: #{final_grade[:letter_grade]}"
      puts ""
      puts "DETAILED SCORES:"
      final_grade[:individual_scores].each do |category, details|
        puts "  #{category.gsub('_', ' ').upcase}: #{details['score']}/10"
        puts "    #{details['justification']}"
        puts ""
      end
    end
  end

  # Step 7: Generate recommendations for improvement
  agent(:generate_recommendations) do
    final_grade = ruby!(:calculate_final_grade).value
    current_scores = final_grade[:individual_scores].map { |cat, details|
      "#{cat}: #{details['score']}/10 - #{details['justification']}"
    }.join("\n")

    template("improvement_recommendations", current_scores: current_scores)
  end
end

# Subroutine for verification checks
execute(:verify_aspect) do
  # This subroutine handles both test_helpers and mocks_and_stubs verification
  ruby(:verification_prompt) do |_, aspect|
    case aspect
    when "test_helpers"
      <<~PROMPT
        Now identify custom test helpers used in this test for the following purpose:

        1. Analyzing if they are used correctly
        2. Understanding test code that has had significant chunks of implementation abstracted away into helpers
        3. Fully understanding custom assertions that are not included by default in Ruby on Rails or part of your base knowledge

        Your grep tool function is vital for this work. It provides 4 lines of context before and after the matching line.

        For example, if you call `grep(string: "def assert_sql")`, the output will include:

        ```
        .test/support/helpers/sql_assertions.rb-101-    end
        .test/support/helpers/sql_assertions.rb-102-    result
        .test/support/helpers/sql_assertions.rb-103-  end
        .test/support/helpers/sql_assertions.rb-104-
        .test/support/helpers/sql_assertions.rb:105:  def assert_sql(*patterns_to_match, **kwargs, &block)
        .test/support/helpers/sql_assertions.rb-106-    mysql_only_test!
        .test/support/helpers/sql_assertions.rb-107-
        .test/support/helpers/sql_assertions.rb-108-    result = T.let(nil, T.nilable(T::Boolean))
        .test/support/helpers/sql_assertions.rb-109-    counter = ActiveRecord::SQLCounter.new(**kwargs)
        ```

        Unfortunately, many test helper methods are undocumented. In those cases (like the example above) the pre-context will be junk. However, there are a number of helper methods that do have very specific and narrow use cases, and those do tend to be well-documented. In those cases, you should use `read_file` to be able to read the full documentation.

        DO NOT FORGET TO PREPEND `def` TO YOUR QUERY TO FIND A METHOD DEFINITION INSTEAD OF USAGES, otherwise you may bring back a very large and useless result set!!!

        Once you are done understanding the custom test helpers used in the test file, analyze and report on whether it seems like any of the helpers are:

        1. Used incorrectly
        2. Used unnecessarily
        3. Any other problem related to the use of helper methods

        Where possible, use your best judgment to make recommendations for how to fix problems that you find, but ONLY related to test helpers.

        Note: You are only being used to help find problems so it is not necessary to report on correct usage of helpers or to make positive comments.
      PROMPT
    when "mocks_and_stubs"
      <<~PROMPT
        Find places in the provided test code where stubbing and mocking are used. Search for the corresponding implementation source code of those dependencies elsewhere in the codebase to validate that the stub or mock matches the implementation that it is doubling. Use the tool functions provided to find and read the dependencies.

        Once you've found the dependencies, verify that any mocks and stubs accurately reflect the real implementation. If there are discrepancies, list them out alphabetically with:

        1. The name of the mocked/stubbed method
        2. What the mock/stub expects in terms of arguments and/or return values
        3. What the actual implementation actually takes as arguments and returns
        4. Suggestions for fixing the discrepancy

        Note: If there are no discrepancies, do not summarize those that accurately reflect their real implementations in the codebase, just respond "All mocks and stubs verified."

        IMPORTANT: There's absolutely no need for you to waste time grepping for methods/functions that you know belong to testing libraries such as Mocha's `expects` and `stubs`. Only search for the implementation of things that are stubbed and/or mocked in the test to verify whether the test code matches the implementation code.
      PROMPT
    end
  end

  agent(:verify_implementation) do
    ruby!(:verification_prompt).value
  end
end