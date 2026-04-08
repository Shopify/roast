# typed: false
# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "active_support/test_case"

module Roast
  module Testing
    # Base test class for writing tests against Roast workflows.
    #
    # Provides sandbox isolation, optional VCR recording/playback for HTTP requests,
    # and helpers for testing agent transcript fixtures.
    #
    # The sandbox copies your +workflow_dir+ INTO a temp directory as a subdirectory,
    # preserving its basename. For example, if +workflow_dir+ is +/home/me/my_project/workflows+,
    # the sandbox will contain +<tmpdir>/workflows/...+. Paths passed to +Workflow.from_file+
    # should include this directory name (e.g. +"workflows/my_workflow.rb"+).
    #
    # Usage:
    #   require "roast/testing/test_case"
    #
    #   class MyWorkflowTest < Roast::Testing::TestCase
    #     # Point to your workflow directory
    #     self.workflow_dir = "path/to/my/workflows"
    #
    #     test "my workflow runs" do
    #       stdout, stderr = in_sandbox(:my_workflow) do
    #         Roast::Workflow.from_file("workflows/my_workflow.rb", EMPTY_PARAMS)
    #       end
    #       assert_empty stderr
    #     end
    #   end
    class TestCase < ActiveSupport::TestCase
      EMPTY_PARAMS = Roast::WorkflowParams.new([].freeze, [].freeze, {}.freeze).freeze

      class_attribute :workflow_dir, default: nil
      class_attribute :cassette_library_dir, default: nil
      class_attribute :sandbox_root, default: nil
      class_attribute :api_key_env_var, default: "OPENAI_API_KEY"
      class_attribute :api_base_env_var, default: "OPENAI_API_BASE"
      class_attribute :fake_api_key, default: "my-token"
      class_attribute :fake_api_base, default: "http://mytestingproxy.local/v1"
      class_attribute :fixture_dir, default: nil

      setup do
        Roast::EventMonitor.reset! if defined?(Roast::EventMonitor)
      end

      teardown do
        verify_command_runner_fixtures!
        Roast::EventMonitor.reset! if defined?(Roast::EventMonitor)
      end

      # Run a block inside an isolated sandbox directory with optional VCR cassette wrapping.
      #
      # Copies workflow_dir INTO a temp directory (preserving the directory basename),
      # sets up fake API credentials (or real ones when recording), and wraps the block
      # in a VCR cassette if VCR is available.
      #
      # @param workflow_id [Symbol, String] identifier used for the sandbox subdirectory and VCR cassette name
      # @return [Array<String>] [stdout, stderr] captured output with temp paths sanitized
      def in_sandbox(workflow_id, &block)
        source_path = resolve_workflow_dir
        tmpdir_root = resolve_sandbox_root
        tmpdir = nil

        FileUtils.mkdir_p(tmpdir_root)

        out, err = capture_io do
          recording = ENV["RECORD_VCR"] == "true"

          with_env(api_key_env_var, recording ? ENV[api_key_env_var] : fake_api_key) do
            with_env(api_base_env_var, recording ? ENV[api_base_env_var] : fake_api_base) do
              in_tmpdir(workflow_id.to_s, tmpdir_root) do |sandbox_dir|
                tmpdir = sandbox_dir
                FileUtils.cp_r(source_path, sandbox_dir)

                with_vcr_cassette(workflow_id, recording: recording, &block)
              end
            end
          end
        end

        # Replace random temp directory path with a standardized value
        if tmpdir
          out.gsub!(tmpdir, "/fake-testing-dir")
          err.gsub!(tmpdir, "/fake-testing-dir")
        end

        if ENV["CI"]
          puts "========= STDOUT ========="
          puts out
          puts "========= STDERR ========="
          puts err
          puts "========= ====== ========="
        end

        [out, err]
      end

      # Set up mocks for CommandRunner.execute that replay from fixture files.
      #
      # Supports multiple sequential invocations. Each spec hash should contain:
      #   - :fixture [String] — base name for fixture files (looks for .stdout.txt/.stdout.log and .stderr.txt/.stderr.log)
      #   - :exit_code [Integer] — simulated exit code (default: 0)
      #   - :expected_args [Array<String>, nil] — if set, asserts CommandRunner args match
      #   - :expected_working_directory [String, Pathname, nil] — if set, asserts working_directory matches
      #   - :expected_timeout [Integer, Float, nil] — if set, asserts timeout matches
      #   - :expected_stdin_content [String, nil] — if set, asserts stdin_content matches
      #
      # Requires the `mocha` gem to be loaded.
      #
      # NOTE: Expected-value assertions (expected_args, etc.) are validated after each
      # call returns, not inside Mocha's +with+ block. This ensures assertion failures
      # surface as normal Minitest failures rather than being swallowed by Mocha as
      # "unexpected invocation" errors.
      #
      # @param specs [Array<Hash>] one or more fixture specifications
      def use_command_runner_fixtures(*specs)
        unless defined?(Mocha)
          raise "use_command_runner_fixtures requires the 'mocha' gem. Add it to your Gemfile."
        end

        call_index = 0
        recorded_calls = []

        loaded = specs.map.with_index do |spec, i|
          fixture_name = spec.fetch(:fixture)
          exit_code = spec.fetch(:exit_code, 0)

          stdout_fixture = load_fixture_file(fixture_name, :stdout)
          stderr_fixture = load_fixture_file(fixture_name, :stderr)

          mock_status = mock("process_status_#{i}")
          mock_status.stubs(exitstatus: exit_code, success?: exit_code == 0, signaled?: false)

          { spec:, stdout: stdout_fixture, stderr: stderr_fixture, status: mock_status }
        end

        expectation = Roast::CommandRunner.stubs(:execute).with do |args, **kwargs|
          if call_index >= loaded.size
            raise "CommandRunner.execute called #{call_index + 1} times, but only #{loaded.size} fixture(s) were provided"
          end

          entry = loaded[call_index]
          call_index += 1

          # Record the call for post-hoc assertion (avoids Mocha swallowing assertion errors)
          recorded_calls << { args: args, kwargs: kwargs, spec: entry[:spec] }

          entry[:stdout].each_line { |line| kwargs[:stdout_handler]&.call(line) }
          entry[:stderr].each_line { |line| kwargs[:stderr_handler]&.call(line) }

          true
        end

        loaded.each_with_index do |entry, i|
          ret = [entry[:stdout], entry[:stderr], entry[:status]]
          expectation = i == 0 ? expectation.returns(ret) : expectation.then.returns(ret)
        end

        # Return the recorded_calls array so callers can assert on call details after
        # execution. The teardown hook validates expectations automatically.
        @_command_runner_recorded_calls = recorded_calls
        @_command_runner_specs = loaded
      end

      # Validate recorded CommandRunner calls against expectations.
      # Called automatically in teardown, or can be called manually after running a workflow.
      def verify_command_runner_fixtures!
        return unless @_command_runner_recorded_calls

        @_command_runner_recorded_calls.each_with_index do |call, i|
          s = call[:spec]
          invocation = i + 1

          assert_equal(s[:expected_args], call[:args], "CommandRunner args mismatch (invocation #{invocation})") if s[:expected_args]
          assert_equal(s[:expected_working_directory], call[:kwargs][:working_directory], "CommandRunner working_directory mismatch (invocation #{invocation})") if s[:expected_working_directory]
          assert_equal(s[:expected_timeout], call[:kwargs][:timeout], "CommandRunner timeout mismatch (invocation #{invocation})") if s[:expected_timeout]
          assert_equal(s[:expected_stdin_content], call[:kwargs][:stdin_content], "CommandRunner stdin_content mismatch (invocation #{invocation})") if s[:expected_stdin_content]
        end
      ensure
        @_command_runner_recorded_calls = nil
        @_command_runner_specs = nil
      end

      private

      def resolve_workflow_dir
        dir = workflow_dir || File.join(Dir.pwd, "examples")
        raise ArgumentError, "Workflow directory not found: #{dir}" unless Dir.exist?(dir)

        dir
      end

      def resolve_sandbox_root
        sandbox_root || File.join(Dir.pwd, "tmp/sandboxes")
      end

      def fixture_path(filename)
        dir = fixture_dir || File.join(Dir.pwd, "test/fixtures")
        File.join(dir, filename)
      end

      # Load a fixture file, trying multiple extensions.
      def load_fixture_file(fixture_name, stream)
        extensions = stream == :stdout ? [".stdout.txt", ".stdout.log"] : [".stderr.txt", ".stderr.log"]
        extensions.each do |ext|
          path = fixture_path("#{fixture_name}#{ext}")
          return File.read(path) if File.exist?(path)
        end
        ""
      end

      def with_vcr_cassette(workflow_id, recording: nil, &block)
        if defined?(VCR)
          configure_vcr_once
          VCR.use_cassette(workflow_id.to_s, record: recording ? :all : :none, &block)
        else
          yield
        end
      end

      VCR_MUTEX = Mutex.new

      def configure_vcr_once
        VCR_MUTEX.synchronize do
          return if Roast::Testing::TestCase.instance_variable_get(:@vcr_configured)

          api_key_replacement = fake_api_key
          api_base_replacement = fake_api_base
          cassette_dir = cassette_library_dir || File.join(Dir.pwd, "test/fixtures/vcr_cassettes")

          VCR.configure do |config|
            config.cassette_library_dir = cassette_dir
            config.hook_into(:webmock) if defined?(WebMock)

            config.filter_sensitive_data("#{api_base_replacement}/chat/completions") do |interaction|
              interaction.request.uri
            end

            config.filter_sensitive_data(api_key_replacement) do |interaction|
              interaction.request.headers["Authorization"]&.first
            end

            config.filter_sensitive_data("<FILTERED>") do |interaction|
              interaction.request.headers["Set-Cookie"]
            end

            config.filter_sensitive_data("<FILTERED>") do |interaction|
              interaction.response.headers["Set-Cookie"]
            end
          end

          Roast::Testing::TestCase.instance_variable_set(:@vcr_configured, true)
        end
      end

      def with_env(key, value)
        original = ENV[key]
        ENV[key] = value
        yield
      ensure
        ENV[key] = original
      end

      def in_tmpdir(prefix, tmpdir_root, &block)
        if ENV["PRESERVE_SANDBOX"]
          dir = Dir.mktmpdir(prefix, tmpdir_root)
          yield(dir)
        else
          Dir.mktmpdir(prefix, tmpdir_root, &block)
        end
      end
    end
  end
end
