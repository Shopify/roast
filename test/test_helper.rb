# frozen_string_literal: true

# Load path setup
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "simplecov"
SimpleCov.start

# Project requires
require "roast"

# Standard library requires
require "benchmark"
require "tmpdir"

# Third-party gem requires
require "active_support/test_case"
require "minitest/autorun"
require "minitest/rg"
require "mocha/minitest"
# Test support files
require "support/improved_assertions"
require "support/test_cog"
require "examples/support/functional_test"
require "vcr"
require "webmock"

# Turn on color during CI since GitHub Actions supports it
if ENV["CI"]
  Minitest::RG.rg!(color: true)
end

# @requires_ancestor: ActiveSupport::TestCase
module CaptureLogOutput
  extend ActiveSupport::Concern

  included do
    setup do
      @logger_output = StringIO.new
      Roast::Log.logger = Logger.new(@logger_output)
    end

    teardown do
      if !passed? && @logger_output.string.present?
        $stderr.puts("\n--- Captured log output (#{name}) ---")
        $stderr.puts(@logger_output.string)
        $stderr.puts("--- End captured log output ---")
      end
      Roast::Log.reset!
    end
  end
end

ActiveSupport::TestCase.include(CaptureLogOutput)

def slow_test!
  skip "slow test" unless ["1", "true"].include?(ENV["ROAST_RUN_SLOW_TESTS"])
end

# Run a block with the Roast logger configured to log at a specific level
#
#: [T] (Integer) { () -> T } -> T
def with_log_level(level, &block)
  original_level = Roast::Log.logger.level
  Roast::Log.logger.level = level
  yield
ensure
  Roast::Log.logger.level = original_level
end

# Run a block with a specific environment variable set
#
#: [T] (String, String) { () -> T } -> T
def with_env(key, value)
  original = ENV[key]
  ENV[key] = value
  yield
ensure
  ENV[key] = original
end

# Create a mock ExecutionManager for wrapping manual cog invocations in tests
#
#: (?scope: Symbol?, ?scope_index: Integer, ?workflow_context: Roast::WorkflowContext?)
def mock_execution_manager(scope: nil, scope_index: 0, workflow_context: nil)
  execution_manager = mock("execution_manager")
  execution_manager.stubs(scope:, scope_index:, workflow_context: workflow_context || create_workflow_context)
  execution_manager
end

# Create a simple WorkflowContext instance with handy default values for use in tests
#
#: (
#|  ?targets: Array[String],
#|  ?args: Array[Symbol],
#|  ?kwargs: Hash[Symbol, String],
#|  ?tmpdir: String,
#|  ?workflow_dir: String,
#| ) -> Roast::WorkflowContext
def create_workflow_context(targets: [], args: [], kwargs: {}, tmpdir: "/tmp", workflow_dir: "/workflow")
  Roast::WorkflowContext.new(
    params: Roast::WorkflowParams.new(targets, args, kwargs),
    tmpdir:,
    workflow_dir:,
  )
end

# Run a cog through the full async execution path for integration testing.
#
# @param cog [Roast::Cog] The cog instance to run
# @param config [Roast::Cog::Config] Optional config (defaults to cog's config class)
# @param scope_value [Object] Optional executor scope value passed to input proc
# @param scope_index [Integer] Optional executor scope index passed to input proc
# @return [Roast::Cog] The cog after execution completes
def run_cog(cog, config: nil, scope_value: nil, scope_index: 0)
  config ||= cog.class.config_class.new

  Sync do
    barrier = Async::Barrier.new
    input_context = Roast::CogInputContext.new
    Fiber[:path] = [Roast::TaskContext::PathElement.new(execution_manager: mock_execution_manager)]

    cog.run!(barrier, config, input_context, scope_value, scope_index)
    barrier.wait
  end

  cog
end

# Sets up a mock for the CommandRunner's execute method that does not actually run a command,
# but instead provides the standard output and standard error lines from fixture files to the
# stdout and stderr handlers provided when execute is invoked. It will also return a Process::Status with the
# provided exit_code (defaulting to 0).
#
# This method can optionally validate that args, working_directory, timeout, and stdin_content values match provided
# expectations.
#
#: (
#|  String,
#|  ?exit_code: Integer,
#|  ?expected_args: Array[String]?,
#|  ?expected_working_directory: (Pathname | String)?,
#|  ?expected_timeout: (Integer | Float)?,
#|  ?expected_stdin_content: String?,
#| ) -> void
def use_command_runner_fixture(
  fixture_name,
  exit_code: 0,
  expected_args: nil,
  expected_working_directory: nil,
  expected_timeout: nil,
  expected_stdin_content: nil
)
  stdout_fixture_file = "test/fixtures/#{fixture_name}.stdout.txt"
  stderr_fixture_file = "test/fixtures/#{fixture_name}.stderr.txt"
  stdout_fixture = File.exist?(stdout_fixture_file) ? File.read(stdout_fixture_file) : ""
  stderr_fixture = File.exist?(stderr_fixture_file) ? File.read(stderr_fixture_file) : ""

  mock_status = mock("process_status")
  mock_status.stubs(exitstatus: exit_code, success?: exit_code == 0, signaled?: false)

  Roast::CommandRunner.stubs(:execute).with do |args, **kwargs|
    assert_equal(expected_args, args, "CommandRunner args mismatch") if expected_args
    assert_equal(expected_working_directory, kwargs[:working_directory], "CommandRunner working_directory mismatch") if expected_working_directory
    assert_equal(expected_timeout, kwargs[:timeout], "CommandRunner timeout mismatch") if expected_timeout
    assert_equal(expected_stdin_content, kwargs[:stdin_content], "CommandRunner stdin_content mismatch") if expected_stdin_content

    stdout_fixture.each_line { |line| kwargs[:stdout_handler]&.call(line) }
    stderr_fixture.each_line { |line| kwargs[:stderr_handler]&.call(line) }

    true
  end.returns([stdout_fixture, stderr_fixture, mock_status])
end

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock

  config.filter_sensitive_data("http://mytestingproxy.local/v1/chat/completions") do |interaction|
    interaction.request.uri
  end

  config.filter_sensitive_data("my-token") do |interaction|
    interaction.request.headers["Authorization"].first
  end

  config.filter_sensitive_data("<FILTERED>") do |interaction|
    interaction.request.headers["Set-Cookie"]
  end

  config.filter_sensitive_data("<FILTERED>") do |interaction|
    interaction.response.headers["Set-Cookie"]
  end
end
