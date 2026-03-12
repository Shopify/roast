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
      Roast::Log.logger = Logger.new(@logger_output).tap do |l|
        l.formatter = Roast::LogFormatter.new(tty: false)
      end
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

# Extract original stdout/stderr content from log output by parsing ❯ and ❯❯ markers.
# Handles multiline log entries by treating non-log-prefix lines as continuations.
#
#: (?logger_output: String) -> [String, String]
def original_streams_from_logger_output(logger_output: @logger_output.string)
  log_prefix_pattern = /^[DIWEFA], \[/
  all_lines = logger_output.lines
  stdout_lines = []
  stderr_lines = []
  current_stream = nil

  all_lines.each do |line|
    if line.match?(log_prefix_pattern)
      if line.include?(" ❯❯")
        current_stream = :stderr
        stderr_lines << line.sub(/^.*❯❯ ?/, "")
      elsif line.include?(" ❯")
        current_stream = :stdout
        stdout_lines << line.sub(/^.*❯ ?/, "")
      else
        current_stream = nil
      end
    elsif current_stream
      (current_stream == :stdout ? stdout_lines : stderr_lines) << line
    end
  end

  [stdout_lines.join, stderr_lines.join]
end

# Sets up a mock for the CommandRunner's execute method that serves fixture files sequentially
# across multiple invocations. Each hash specifies a fixture and optional expectations for one call.
#
# Each hash supports:
#   fixture:                      (String, required) fixture name under test/fixtures/
#   exit_code:                    (Integer, default 0)
#   expected_args:                (Array[String]?)
#   expected_working_directory:   (Pathname | String)?
#   expected_timeout:             (Integer | Float)?
#   expected_stdin_content:       (String?)
#
#: (*Hash[Symbol, untyped]) -> void
def use_command_runner_fixtures(*specs)
  call_index = 0

  # Pre-load all fixtures and mock statuses so they're ready at call time
  loaded = specs.map do |spec|
    fixture_name = spec.fetch(:fixture)
    exit_code = spec.fetch(:exit_code, 0)

    stdout_fixture = load_command_runner_fixture_file(fixture_name, :stdout)
    stderr_fixture = load_command_runner_fixture_file(fixture_name, :stderr)

    mock_status = mock("process_status_#{call_index}")
    mock_status.stubs(exitstatus: exit_code, success?: exit_code == 0, signaled?: false)

    { spec:, stdout: stdout_fixture, stderr: stderr_fixture, status: mock_status }
  end

  expectation = Roast::CommandRunner.stubs(:execute).with do |args, **kwargs|
    assert call_index < loaded.size,
      "CommandRunner.execute called #{call_index + 1} times, but only #{loaded.size} fixture(s) were provided"

    entry = loaded[call_index]
    spec = entry[:spec]
    call_index += 1

    assert_equal(spec[:expected_args], args, "CommandRunner args mismatch (invocation #{call_index})") if spec[:expected_args]
    assert_equal(spec[:expected_working_directory], kwargs[:working_directory], "CommandRunner working_directory mismatch (invocation #{call_index})") if spec[:expected_working_directory]
    assert_equal(spec[:expected_timeout], kwargs[:timeout], "CommandRunner timeout mismatch (invocation #{call_index})") if spec[:expected_timeout]
    assert_equal(spec[:expected_stdin_content], kwargs[:stdin_content], "CommandRunner stdin_content mismatch (invocation #{call_index})") if spec[:expected_stdin_content]

    entry[:stdout].each_line { |line| kwargs[:stdout_handler]&.call(line) }
    entry[:stderr].each_line { |line| kwargs[:stderr_handler]&.call(line) }

    true
  end

  # Chain sequential return values: .returns(first).then.returns(second).then.returns(third)...
  loaded.each_with_index do |entry, i|
    ret = [entry[:stdout], entry[:stderr], entry[:status]]
    expectation = i == 0 ? expectation.returns(ret) : expectation.then.returns(ret)
  end
end

# Load a CommandRunner fixture file, trying .stdout.txt then .stdout.log (and likewise for stderr).
#
#: (String, Symbol) -> String
def load_command_runner_fixture_file(fixture_name, stream)
  extensions = stream == :stdout ? [".stdout.txt", ".stdout.log"] : [".stderr.txt", ".stderr.log"]
  extensions.each do |ext|
    path = "test/fixtures/#{fixture_name}#{ext}"
    return File.read(path) if File.exist?(path)
  end
  ""
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
