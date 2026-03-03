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
      EMPTY_PARAMS = Roast::WorkflowParams.new([], [], {})

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
        Roast::EventMonitor.reset! if defined?(Roast::EventMonitor)
      end

      # Run a block inside an isolated sandbox directory with optional VCR cassette wrapping.
      #
      # Copies workflow_dir contents into a temp directory, sets up fake API credentials
      # (or real ones when recording), and wraps the block in a VCR cassette if VCR is available.
      #
      # @param workflow_id [Symbol, String] identifier used for the sandbox subdirectory and VCR cassette name
      # @return [Array<String>] [stdout, stderr] captured output with temp paths sanitized
      def in_sandbox(workflow_id, &block)
        source_path = resolve_workflow_dir
        tmpdir_root = resolve_sandbox_root
        tmpdir = nil

        FileUtils.mkdir_p(tmpdir_root) unless Dir.exist?(tmpdir_root)

        out, err = capture_io do
          recording = ENV["RECORD_VCR"]

          with_env(api_key_env_var, recording ? ENV[api_key_env_var] : fake_api_key) do
            with_env(api_base_env_var, recording ? ENV[api_base_env_var] : fake_api_base) do
              in_tmpdir(workflow_id.to_s, tmpdir_root) do |sandbox_dir|
                tmpdir = sandbox_dir
                FileUtils.cp_r(source_path, sandbox_dir)

                with_vcr_cassette(workflow_id, recording: recording) do
                  block.call
                end
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

      # Set up a mock for CommandRunner.execute that replays from fixture files.
      #
      # Loads stdout/stderr from test/fixtures/<fixture_name>.stdout.txt and .stderr.txt,
      # feeds them to the handlers, and returns a mock Process::Status.
      #
      # @param fixture_name [String] base name of the fixture files
      # @param exit_code [Integer] simulated exit code (default: 0)
      # @param expected_args [Array<String>, nil] if set, asserts CommandRunner args match
      # @param expected_working_directory [String, Pathname, nil] if set, asserts working_directory matches
      # @param expected_timeout [Integer, Float, nil] if set, asserts timeout matches
      # @param expected_stdin_content [String, nil] if set, asserts stdin_content matches
      def use_command_runner_fixture(
        fixture_name,
        exit_code: 0,
        expected_args: nil,
        expected_working_directory: nil,
        expected_timeout: nil,
        expected_stdin_content: nil
      )
        stdout_fixture_file = fixture_path("#{fixture_name}.stdout.txt")
        stderr_fixture_file = fixture_path("#{fixture_name}.stderr.txt")
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

      private

      def resolve_workflow_dir
        dir = workflow_dir || File.join(Dir.pwd, "examples")
        raise "Workflow directory not found: #{dir}" unless Dir.exist?(dir)

        dir
      end

      def resolve_sandbox_root
        sandbox_root || File.join(Dir.pwd, "tmp/sandboxes")
      end

      def fixture_path(filename)
        dir = fixture_dir || File.join(Dir.pwd, "test/fixtures")
        File.join(dir, filename)
      end

      def with_vcr_cassette(workflow_id, recording: nil, &block)
        if defined?(VCR)
          configure_vcr_once
          VCR.use_cassette(workflow_id.to_s, record: recording ? :all : :none, &block)
        else
          block.call
        end
      end

      def configure_vcr_once
        return if self.class.instance_variable_get(:@vcr_configured)

        # Skip auto-configuration if VCR is already configured (e.g., by the host test_helper.rb)
        if VCR.configuration.cassette_library_dir
          self.class.instance_variable_set(:@vcr_configured, true)
          return
        end

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

        self.class.instance_variable_set(:@vcr_configured, true)
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
          block.call(dir)
        else
          Dir.mktmpdir(prefix, tmpdir_root, &block)
        end
      end
    end
  end
end
