# frozen_string_literal: true

class RunCoverage < Roast::Workflow::BaseStep
  def call
    # Run the test with coverage analysis
    run_test_with_coverage
  end

  private

  def run_test_with_coverage
    subject_file = workflow.output["read_dependencies"]
    subject_file = subject_file.match(%r{<sut>(.*?)</sut>})&.[](1) || subject_file
    test_file = workflow.file
    extension = File.extname(test_file).gsub(".", "")

    # Handle JS/TS test files
    extension = "js" if ["js", "jsx", "ts", "tsx"].include?(extension)

    # Get the absolute path to the test_runner executable
    test_runner_path = File.expand_path("#{extension}_test_runner", __dir__)

    # Make sure the test_runner executable exists
    unless File.exist?(test_runner_path)
      Roast::Helpers::Logger.error("Test runner executable not found: #{test_runner_path}")
      exit(1)
    end

    # Resolve paths to prevent issues when pwd differs from project root
    resolved_subject_file = Roast::Helpers::PathResolver.resolve(subject_file)
    unless File.exist?(resolved_subject_file)
      Roast::Helpers::Logger.error("Subject file not found: #{resolved_subject_file}")
      exit(1)
    end

    resolved_test_file = Roast::Helpers::PathResolver.resolve(test_file)
    unless File.exist?(resolved_test_file)
      Roast::Helpers::Logger.error("Test file not found: #{resolved_test_file}")
      exit(1)
    end

    # Run the test_runner using shadowenv for environment consistency
    command = "shadowenv exec --dir . -- #{test_runner_path} #{resolved_test_file} #{resolved_subject_file}"
    output, status = Open3.capture2(command)

    unless status.success?
      Roast::Helpers::Logger.error("Test runner exited with non-zero status: #{status.exitstatus}")
      Roast::Helpers::Logger.error(output)
      exit(status.exitstatus)
    end

    output
  end
end
