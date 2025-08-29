# frozen_string_literal: true

require "test_helper"

# This test suite validates the example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "basic_prompt_workflow" do
    VCR.use_cassette("basic_prompt_workflow") do
      out, _ = in_sandbox with_workflow: :basic_prompt_workflow, with_sample_data: "skateboard_orders.csv" do
        roast("execute", "basic_prompt_workflow", "-t", "skateboard_orders.csv")
      end

      expected_output = <<~OUTPUT
        📖 Reading file: /fake-testing-dir
        📖 Reading file: /fake-testing-dir/roast
        📖 Reading file: /fake-testing-dir/roast/skateboard_orders.csv
        🔍 Grepping for string: ,CA,
        🔍 Grepping for string: ,FL,
        📖 Reading file: /fake-testing-dir/roast/skateboard_orders.csv
        📖 Reading file: /fake-testing-dir/roast/skateboard_orders.csv
        🔍 Grepping for string: Complete Skateboard
        🔍 Grepping for string: Complete Skateboard
        🔍 Grepping for string: Complete Skateboard
        Based on the analysis of the `skateboard_orders.csv` file, here are the key insights:

        1.  **Customer Demographics (Geographical):** A significant portion of your customers are located in California (CA) and Florida (FL). This suggests these states are strong markets for your business.
        2.  **Most Popular Product Category:** "Complete Skateboard" is your most frequently sold product category. This indicates a high demand for ready-to-ride skateboards among your customers.

        Would you like me to delve deeper into any of these areas, such as quantifying the exact number of customers per state or the sales volume of "Complete Skateboards"? I can also look into other aspects like sales trends over time, average order value, or popular payment methods.
      OUTPUT

      assert_equal expected_output.squish, out.squish
    end
  end

  test "available_tools_demo workflow" do
    expected_output = <<~OUTPUT
      🔧 Running command: pwd
      🔧 Running command: ls
      🔍 Grepping for string: .rb
      🔍 Grepping for string: *.rb
      🔍 Grepping for string: ruby
      📖 Reading file: /fake-testing-dir/roast
      📖 Reading file: /fake-testing-dir/roast/available_tools_demo
      📝 Writing to file: summary.txt
      Summary of Directory Exploration:

      In the 'roast' directory, the only subdirectory found is 'available_tools_demo'. Within this subdirectory, two files were identified:
      - README.md (1481 bytes)
      - workflow.yml (482 bytes)

      Additionally, there are three subdirectories:
      - analyze_files
      - explore_directory
      - write_summary

      No Ruby files (.rb) were found during the exploration.🔧 Running command: echo Summary written to summary.txt
      The summary of the directory exploration has been successfully written to `summary.txt`.#{" "}

      Completion message: **Summary written to summary.txt**.
    OUTPUT

    VCR.use_cassette("available_tools") do
      assert_from_sandbox with_workflow: :available_tools_demo, expected_output: do
        roast("execute", "available_tools_demo")
      end
    end
  end
end
