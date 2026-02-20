# frozen_string_literal: true

require "test_helper"

module Roast
  class CLITest < ActiveSupport::TestCase
    # ── split_at_separator ──

    test "split_at_separator with no separator returns all args as roast_args and empty extra" do
      roast_args, extra_args = CLI.send(:split_at_separator, ["execute", "workflow.rb", "target"])
      assert_equal ["execute", "workflow.rb", "target"], roast_args
      assert_equal [], extra_args
    end

    test "split_at_separator splits on -- correctly" do
      roast_args, extra_args = CLI.send(:split_at_separator, ["workflow.rb", "--", "foo=bar", "hello"])
      assert_equal ["workflow.rb"], roast_args
      assert_equal ["foo=bar", "hello"], extra_args
    end

    test "split_at_separator with -- at start yields empty roast_args" do
      roast_args, extra_args = CLI.send(:split_at_separator, ["--", "foo", "bar"])
      assert_equal [], roast_args
      assert_equal ["foo", "bar"], extra_args
    end

    test "split_at_separator with -- at end yields empty extra_args" do
      roast_args, extra_args = CLI.send(:split_at_separator, ["workflow.rb", "--"])
      assert_equal ["workflow.rb"], roast_args
      assert_equal [], extra_args
    end

    test "split_at_separator with empty input" do
      roast_args, extra_args = CLI.send(:split_at_separator, [])
      assert_equal [], roast_args
      assert_equal [], extra_args
    end

    test "split_at_separator does not mutate the original array" do
      original = ["a", "--", "b"]
      CLI.send(:split_at_separator, original)
      assert_equal ["a", "--", "b"], original
    end

    # ── parse_custom_workflow_args ──

    test "parse_custom_workflow_args with empty input" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, [])
      assert_equal [], args
      assert_equal({}, kwargs)
    end

    test "parse_custom_workflow_args parses simple flag args as symbols" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, ["hello", "world"])
      assert_equal [:hello, :world], args
      assert_equal({}, kwargs)
    end

    test "parse_custom_workflow_args parses key=value as kwargs" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, ["foo=bar", "count=42"])
      assert_equal [], args
      assert_equal({ foo: "bar", count: "42" }, kwargs)
    end

    test "parse_custom_workflow_args handles mixed args and kwargs" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, ["verbose", "foo=bar", "debug", "name=test"])
      assert_equal [:verbose, :debug], args
      assert_equal({ foo: "bar", name: "test" }, kwargs)
    end

    test "parse_custom_workflow_args strips leading single dash from args" do
      args, _ = CLI.send(:parse_custom_workflow_args, ["-verbose"])
      assert_equal [:verbose], args
    end

    test "parse_custom_workflow_args strips leading double dash from args" do
      args, _ = CLI.send(:parse_custom_workflow_args, ["--verbose"])
      assert_equal [:verbose], args
    end

    test "parse_custom_workflow_args strips leading dashes from kwargs keys" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, ["--foo=bar", "-name=test"])
      assert_equal [], args
      assert_equal({ foo: "bar", name: "test" }, kwargs)
    end

    test "parse_custom_workflow_args does not strip bare double-dash prefix" do
      # A bare "--" would not normally appear here (split_at_separator already consumed it),
      # but the regex requires a non-dash char after the prefix, so "--" is preserved.
      args, _kwargs = CLI.send(:parse_custom_workflow_args, ["--"])
      assert_equal [:"--"], args
    end

    test "parse_custom_workflow_args handles value with equals sign" do
      args, kwargs = CLI.send(:parse_custom_workflow_args, ["query=a=b=c"])
      assert_equal [], args
      assert_equal({ query: "a=b=c" }, kwargs)
    end

    # ── resolve_workflow_path ──

    test "resolve_workflow_path returns nil for nonexistent file" do
      result = CLI.send(:resolve_workflow_path, "/nonexistent/path/to/workflow.rb")
      assert_nil result
    end

    test "resolve_workflow_path resolves an absolute path that exists" do
      path = File.expand_path("examples/outputs.rb")
      result = CLI.send(:resolve_workflow_path, path)
      assert_instance_of Pathname, result
      assert result.exist?
      assert_equal Pathname.new(path).realpath, result
    end

    test "resolve_workflow_path resolves a relative path from cwd" do
      result = CLI.send(:resolve_workflow_path, "examples/outputs.rb")
      assert_instance_of Pathname, result
      assert result.exist?
    end

    test "resolve_workflow_path uses ROAST_WORKING_DIRECTORY when set" do
      project_root = File.expand_path("../..", __dir__)
      with_env("ROAST_WORKING_DIRECTORY", project_root) do
        result = CLI.send(:resolve_workflow_path, "examples/outputs.rb")
        assert_instance_of Pathname, result
        assert result.exist?
      end
    end

    test "resolve_workflow_path returns nil when relative path is not found" do
      result = CLI.send(:resolve_workflow_path, "definitely/not/a/real/workflow.rb")
      assert_nil result
    end

    # ── help ──

    test "help writes usage information to stderr" do
      output = capture_io { CLI.send(:help) }[1]
      assert_match(/Usage: roast/, output)
      assert_match(/Commands:/, output)
      assert_match(/execute/, output)
      assert_match(/version/, output)
      assert_match(/help/, output)
    end

    # ── start (version) ──

    test "start with version prints the version" do
      output, _stderr = capture_io { CLI.start(["version"]) }
      assert_match(/Roast version #{Regexp.escape(Roast::VERSION)}/, output)
    end

    # ── start (help) ──

    test "start with help shows help text" do
      _stdout, stderr = capture_io { CLI.start(["help"]) }
      assert_match(/Usage: roast/, stderr)
    end

    test "start with -h flag shows help text" do
      _stdout, stderr = capture_io { CLI.start(["-h"]) }
      assert_match(/Usage: roast/, stderr)
    end

    test "start with --help flag shows help text" do
      _stdout, stderr = capture_io { CLI.start(["--help"]) }
      assert_match(/Usage: roast/, stderr)
    end

    # ── start (no args) ──

    test "start with no arguments shows help" do
      _stdout, stderr = capture_io { CLI.start([]) }
      assert_match(/Usage: roast/, stderr)
    end

    # ── start (unknown command) ──

    test "start with unknown command prints error to stderr and exits" do
      _stdout, stderr = capture_io do
        error = assert_raises(SystemExit) { CLI.start(["not_a_real_command_or_file"]) }
        assert_equal 1, error.status
      end
      assert_match(/Could not find command or workflow file "not_a_real_command_or_file"/, stderr)
      assert_match(/Usage: roast/, stderr)
    end

    # ── start (execute without workflow) ──

    test "start with execute but no workflow file prints error to stderr and exits" do
      _stdout, stderr = capture_io do
        error = assert_raises(SystemExit) { CLI.start(["execute"]) }
        assert_equal 1, error.status
      end
      assert_match(/Workflow file is required/, stderr)
      assert_match(/Usage: roast/, stderr)
    end

    test "start with execute and nonexistent workflow prints error to stderr and exits" do
      _stdout, stderr = capture_io do
        error = assert_raises(SystemExit) { CLI.start(["execute", "nonexistent_workflow.rb"]) }
        assert_equal 1, error.status
      end
      assert_match(/Workflow file not found: nonexistent_workflow\.rb/, stderr)
      assert_match(/Usage: roast/, stderr)
    end

    # ── start dispatches to run_execute ──

    test "start with execute command calls run_execute" do
      CLI.expects(:run_execute).with(["examples/outputs.rb"], []).once
      CLI.start(["execute", "examples/outputs.rb"])
    end

    test "start with execute and extra args passes them through" do
      CLI.expects(:run_execute).with(["examples/outputs.rb"], ["foo=bar", "hello"]).once
      CLI.start(["execute", "examples/outputs.rb", "--", "foo=bar", "hello"])
    end

    test "start with workflow file as first arg calls run_execute" do
      CLI.expects(:run_execute).with(["examples/outputs.rb"], []).once
      CLI.start(["examples/outputs.rb"])
    end

    test "start with workflow file passes targets and extra args" do
      CLI.expects(:run_execute).with(["examples/outputs.rb", "target1", "target2"], ["--verbose"]).once
      CLI.start(["examples/outputs.rb", "target1", "target2", "--", "--verbose"])
    end
  end
end
