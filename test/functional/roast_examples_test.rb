# frozen_string_literal: true

require "test_helper"

# This test suite validates the example workflows in `examples/`.
class RoastExamplesTest < FunctionalTest
  test "available_tools_demo workflow" do
    VCR.use_cassette("available_tools") do
      out, _ = in_sandbox with_workflow: :available_tools_demo do
        roast("execute", "available_tools_demo")
      end

      expected_output = <<~OUTPUT
        🔧 Running command: pwd
        🔧 Running command: ls
        🔍 Grepping for string: *.rb
        🔍 Grepping for string: .rb
        📝 Writing to file: summary.txt
        Summary of exploration:

        - Current working directory: /private/var/folders/dh/jj0r0qdd48d_3fcsl49l6_qh0000gn/T/d20250826-13677-63p5o6
        - Found one subdirectory named 'roast'.
        - No Ruby files were found during the search.🔧 Running command: echo Summary has been written to summary.txt
        The summary of the exploration has been successfully written to `summary.txt`.

        ### Completion Message:
        Summary has been written to `summary.txt`.
      OUTPUT

      assert_equal expected_output.squish, out.squish
    end
  end
end
