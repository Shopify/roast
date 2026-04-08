# frozen_string_literal: true

require "test_helper"
require "roast/testing/test_case"

module Roast
  module Testing
    class TestCaseUnitTest < ActiveSupport::TestCase
      test "EMPTY_PARAMS is frozen" do
        assert_predicate TestCase::EMPTY_PARAMS, :frozen?
      end

      test "EMPTY_PARAMS has empty arrays and hash" do
        params = TestCase::EMPTY_PARAMS
        assert_empty params.targets
        assert_empty params.args
        assert_empty params.kwargs
      end

      test "resolve_workflow_dir raises ArgumentError for missing directory" do
        klass = Class.new(TestCase) do
          self.workflow_dir = "/nonexistent/path/that/does/not/exist"
        end
        instance = klass.new("test")
        assert_raises(ArgumentError) { instance.send(:resolve_workflow_dir) }
      end

      test "resolve_workflow_dir uses workflow_dir when set and exists" do
        klass = Class.new(TestCase) do
          self.workflow_dir = Dir.pwd
        end
        instance = klass.new("test")
        assert_equal(Dir.pwd, instance.send(:resolve_workflow_dir))
      end

      test "resolve_sandbox_root uses sandbox_root when set" do
        klass = Class.new(TestCase) do
          self.sandbox_root = "/custom/sandbox"
        end
        instance = klass.new("test")
        assert_equal("/custom/sandbox", instance.send(:resolve_sandbox_root))
      end

      test "resolve_sandbox_root defaults to tmp/sandboxes" do
        instance = TestCase.new("test")
        assert_equal(File.join(Dir.pwd, "tmp/sandboxes"), instance.send(:resolve_sandbox_root))
      end

      test "fixture_path uses fixture_dir when set" do
        klass = Class.new(TestCase) do
          self.fixture_dir = "/custom/fixtures"
        end
        instance = klass.new("test")
        assert_equal("/custom/fixtures/my_file.txt", instance.send(:fixture_path, "my_file.txt"))
      end

      test "fixture_path defaults to test/fixtures" do
        instance = TestCase.new("test")
        assert_equal(File.join(Dir.pwd, "test/fixtures/my_file.txt"), instance.send(:fixture_path, "my_file.txt"))
      end

      test "load_fixture_file returns empty string when no fixture files exist" do
        klass = Class.new(TestCase) do
          self.fixture_dir = "/nonexistent"
        end
        instance = klass.new("test")
        assert_equal("", instance.send(:load_fixture_file, "missing_fixture", :stdout))
        assert_equal("", instance.send(:load_fixture_file, "missing_fixture", :stderr))
      end

      test "load_fixture_file reads stdout fixture" do
        instance = TestCase.new("test")
        result = instance.send(:load_fixture_file, "agent_transcripts/simple_agent", :stdout)
        refute_empty result
      end

      test "with_env temporarily sets and restores environment variable" do
        original = ENV["ROAST_TEST_CASE_TEST_VAR"]
        ENV["ROAST_TEST_CASE_TEST_VAR"] = "original_value"

        instance = TestCase.new("test")
        instance.send(:with_env, "ROAST_TEST_CASE_TEST_VAR", "temporary_value") do
          assert_equal("temporary_value", ENV["ROAST_TEST_CASE_TEST_VAR"])
        end
        assert_equal("original_value", ENV["ROAST_TEST_CASE_TEST_VAR"])
      ensure
        ENV["ROAST_TEST_CASE_TEST_VAR"] = original
      end

      test "with_env restores nil when variable was unset" do
        ENV.delete("ROAST_TEST_CASE_UNSET_VAR")
        instance = TestCase.new("test")

        instance.send(:with_env, "ROAST_TEST_CASE_UNSET_VAR", "temp") do
          assert_equal("temp", ENV["ROAST_TEST_CASE_UNSET_VAR"])
        end
        assert_nil(ENV["ROAST_TEST_CASE_UNSET_VAR"])
      end

      test "with_env restores original value even on exception" do
        ENV["ROAST_TEST_CASE_RESTORE_VAR"] = "keep_me"
        instance = TestCase.new("test")

        assert_raises(RuntimeError) do
          instance.send(:with_env, "ROAST_TEST_CASE_RESTORE_VAR", "temp") do
            raise "boom"
          end
        end
        assert_equal("keep_me", ENV["ROAST_TEST_CASE_RESTORE_VAR"])
      ensure
        ENV.delete("ROAST_TEST_CASE_RESTORE_VAR")
      end

      test "in_tmpdir creates temporary directory and yields it" do
        instance = TestCase.new("test")
        yielded_dir = nil

        instance.send(:in_tmpdir, "test_prefix", Dir.tmpdir) do |dir|
          yielded_dir = dir
          assert(Dir.exist?(dir))
          assert_includes(dir, "test_prefix")
        end

        refute(Dir.exist?(yielded_dir))
      end

      test "in_tmpdir with PRESERVE_SANDBOX keeps directory" do
        instance = TestCase.new("test")
        yielded_dir = nil

        original = ENV["PRESERVE_SANDBOX"]
        ENV["PRESERVE_SANDBOX"] = "true"
        begin
          instance.send(:in_tmpdir, "preserve_test", Dir.tmpdir) do |dir|
            yielded_dir = dir
          end
        ensure
          ENV["PRESERVE_SANDBOX"] = original
        end

        assert(Dir.exist?(yielded_dir))
        FileUtils.rm_rf(yielded_dir)
      end

      test "class attributes have correct defaults" do
        assert_nil(TestCase.workflow_dir)
        assert_nil(TestCase.cassette_library_dir)
        assert_nil(TestCase.sandbox_root)
        assert_equal("OPENAI_API_KEY", TestCase.api_key_env_var)
        assert_equal("OPENAI_API_BASE", TestCase.api_base_env_var)
        assert_equal("my-token", TestCase.fake_api_key)
        assert_equal("http://mytestingproxy.local/v1", TestCase.fake_api_base)
        assert_nil(TestCase.fixture_dir)
      end

      test "class attributes are inheritable" do
        klass = Class.new(TestCase) do
          self.workflow_dir = "/custom"
          self.fixture_dir = "/custom_fixtures"
        end

        assert_equal("/custom", klass.workflow_dir)
        assert_equal("/custom_fixtures", klass.fixture_dir)
        assert_nil(TestCase.workflow_dir)
        assert_nil(TestCase.fixture_dir)
      end

      test "configure_vcr_once guard is anchored on TestCase base class" do
        # The guard uses Roast::Testing::TestCase (not self.class) to prevent
        # duplicate VCR configuration from subclasses. Verify by checking that
        # a subclass does NOT have its own @vcr_configured ivar — only the base does.
        subclass = Class.new(TestCase)
        refute(
          subclass.instance_variable_defined?(:@vcr_configured),
          "Subclass should NOT have its own @vcr_configured ivar",
        )
      end
    end

    # Integration tests for in_sandbox — uses a real workflow directory
    class TestCaseInSandboxTest < TestCase
      self.workflow_dir = File.join(Dir.pwd, "test/fixtures/testing")
      self.sandbox_root = File.join(Dir.tmpdir, "roast_test_sandboxes_#{Process.pid}")

      teardown do
        FileUtils.rm_rf(self.class.sandbox_root) if Dir.exist?(self.class.sandbox_root)
      end

      test "in_sandbox returns stdout and stderr as strings" do
        out, err = in_sandbox(:basic_test) do
          $stdout.print("hello stdout")
          $stderr.print("hello stderr")
        end

        assert_instance_of(String, out)
        assert_instance_of(String, err)
        assert_includes(out, "hello stdout")
        assert_includes(err, "hello stderr")
      end

      test "in_sandbox sanitizes temp directory paths in output" do
        # We need to print the actual sandbox tmpdir path to test sanitization.
        # The sandbox_root is known, so we find the sandbox subdir via it.
        sandbox_root = self.class.sandbox_root
        sandbox_subdir = nil

        out, _err = in_sandbox(:path_sanitization) do
          # Find the sandbox dir that was just created under sandbox_root
          dirs = Dir.glob("#{sandbox_root}/path_sanitization*")
          sandbox_subdir = dirs.first
          $stdout.print(sandbox_subdir) if sandbox_subdir
        end

        # The real temp path should be replaced with /fake-testing-dir
        assert_includes(out, "/fake-testing-dir")
        refute_includes(out, sandbox_root) if sandbox_subdir
      end

      test "in_sandbox copies workflow_dir into sandbox as subdirectory" do
        sandbox_root = self.class.sandbox_root

        in_sandbox(:copy_test) do
          # Find the sandbox dir under sandbox_root
          dirs = Dir.glob("#{sandbox_root}/copy_test*")
          sandbox_dir = dirs.first
          assert(sandbox_dir, "Expected sandbox directory to exist under #{sandbox_root}")

          # workflow_dir is test/fixtures/testing, so cp_r creates testing/ inside sandbox
          copied = File.join(sandbox_dir, "testing", "hello_workflow.rb")
          assert(File.exist?(copied), "Expected hello_workflow.rb at #{copied}")
        end
      end

      test "in_sandbox sets fake API credentials during playback" do
        in_sandbox(:env_test) do
          assert_equal("my-token", ENV["OPENAI_API_KEY"])
          assert_equal("http://mytestingproxy.local/v1", ENV["OPENAI_API_BASE"])
        end
      end

      test "in_sandbox cleans up sandbox directory after test" do
        sandbox_root = self.class.sandbox_root
        sandbox_subdir = nil

        in_sandbox(:cleanup_test) do
          dirs = Dir.glob("#{sandbox_root}/cleanup_test*")
          sandbox_subdir = dirs.first
          assert(sandbox_subdir && Dir.exist?(sandbox_subdir), "Sandbox should exist during block")
        end

        # After in_sandbox returns, the temp dir should be cleaned up
        assert(sandbox_subdir, "Should have captured sandbox path")
        refute(Dir.exist?(sandbox_subdir), "Sandbox directory should be cleaned up after in_sandbox")
      end
    end

    # Integration tests for use_command_runner_fixtures
    class TestCaseCommandRunnerTest < TestCase
      self.workflow_dir = File.join(Dir.pwd, "test/fixtures/testing")
      self.fixture_dir = File.join(Dir.pwd, "test/fixtures/testing")

      test "use_command_runner_fixtures replays single fixture" do
        use_command_runner_fixtures({ fixture: "cmd_fixture_test" })

        stdout_lines = []
        stderr_lines = []
        stdout, _stderr, status = Roast::CommandRunner.execute(
          ["echo", "test"],
          stdout_handler: ->(line) { stdout_lines << line },
          stderr_handler: ->(line) { stderr_lines << line },
        )

        assert_predicate(status, :success?)
        assert_includes(stdout, "fixture stdout line 1")
        assert_equal(["fixture stderr line 1\n"], stderr_lines)
      end

      test "use_command_runner_fixtures replays sequential fixtures" do
        use_command_runner_fixtures(
          { fixture: "cmd_fixture_test" },
          { fixture: "cmd_fixture_second" },
        )

        # First call
        stdout1, _stderr1, _status1 = Roast::CommandRunner.execute(
          ["first"],
          stdout_handler: ->(_line) {},
          stderr_handler: ->(_line) {},
        )
        assert_includes(stdout1, "fixture stdout line 1")

        # Second call
        stdout2, _stderr2, _status2 = Roast::CommandRunner.execute(
          ["second"],
          stdout_handler: ->(_line) {},
          stderr_handler: ->(_line) {},
        )
        assert_includes(stdout2, "second fixture stdout")
      end

      test "use_command_runner_fixtures raises on excess calls" do
        use_command_runner_fixtures({ fixture: "cmd_fixture_test" })

        # First call succeeds
        Roast::CommandRunner.execute(
          ["ok"],
          stdout_handler: ->(_line) {},
          stderr_handler: ->(_line) {},
        )

        # Second call should raise
        error = assert_raises(RuntimeError) do
          Roast::CommandRunner.execute(
            ["too_many"],
            stdout_handler: ->(_line) {},
            stderr_handler: ->(_line) {},
          )
        end
        assert_match(/called 2 times.*only 1 fixture/, error.message)
      end
    end
  end
end
