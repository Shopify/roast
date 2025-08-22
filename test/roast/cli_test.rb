# frozen_string_literal: true

require "test_helper"

class RoastCLITest < ActiveSupport::TestCase
  def test_execute_with_workflow_yml_path
    # Use a real workflow file to avoid file system issues
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")

      # Mock the WorkflowRunner to prevent actual execution
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).once
      Roast::Workflow::WorkflowRunner.expects(:new).with(workflow_file, [], { executor: "default" }).returns(mock_runner)

      # Execute using the new CLI::Kit entry point
      args = ["execute", workflow_file]
      capture_io do
        Roast::EntryPoint.call(args)
      end
    end
  end

  def test_execute_with_conventional_path
    # Test conventional path resolution
    Dir.mktmpdir do |tmpdir|
      workflow_name = "my_workflow"
      workflow_dir = File.join(tmpdir, "roast", workflow_name)
      FileUtils.mkdir_p(workflow_dir)
      workflow_file = File.join(workflow_dir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")

      # Mock the WorkflowRunner to prevent actual execution - use realpath to match what File.expand_path returns
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).once
      Roast::Workflow::WorkflowRunner.expects(:new).with(File.realpath(workflow_file), [], { executor: "default" }).returns(mock_runner)

      # Execute using the new CLI::Kit entry point from the tmpdir
      Dir.chdir(tmpdir) do
        args = ["execute", workflow_name]
        capture_io do
          Roast::EntryPoint.call(args)
        end
      end
    end
  end

  def test_execute_with_directory_path_raises_error
    # Use a real directory to trigger the error
    Dir.mktmpdir do |tmpdir|
      # Create a roast directory structure where workflow.yml is a directory instead of a file
      workflow_dir = File.join(tmpdir, "roast", "test_workflow")
      FileUtils.mkdir_p(workflow_dir)
      # Create a workflow.yml directory instead of a file to trigger the error
      FileUtils.mkdir_p(File.join(workflow_dir, "workflow.yml"))

      args = ["execute", "test_workflow"]
      assert_raises(SystemExit) do
        Dir.chdir(tmpdir) do
          capture_io do
            Roast::EntryPoint.call(args)
          end
        end
      end
    end
  end

  def test_execute_with_files_passes_files_to_parser
    # Test that files are passed through correctly
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")
      files = ["file1.rb", "file2.rb"]

      # Mock the WorkflowRunner to prevent actual execution
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).once
      Roast::Workflow::WorkflowRunner.expects(:new).with(workflow_file, files, { executor: "default" }).returns(mock_runner)

      # Execute using the new CLI::Kit entry point
      args = ["execute", workflow_file, *files]
      capture_io do
        Roast::EntryPoint.call(args)
      end
    end
  end

  def test_execute_with_options_passes_options_to_parser
    # Test that options are passed through correctly
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")

      # Mock the WorkflowRunner to prevent actual execution
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).once
      Roast::Workflow::WorkflowRunner.expects(:new).with(workflow_file, [], { executor: "default", verbose: true, concise: true }).returns(mock_runner)

      # Execute using the new CLI::Kit entry point with options
      args = ["execute", "--verbose", "--concise", workflow_file]
      capture_io do
        Roast::EntryPoint.call(args)
      end
    end
  end

  def test_list_with_no_roast_directory
    # Create a temporary directory without a roast/ subdirectory
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        # Expect an exit since CLI::Kit aborts on error
        assert_raises(SystemExit) do
          capture_io do
            Roast::EntryPoint.call(["list"])
          end
        end
      end
    end
  end

  def test_list_with_empty_roast_directory
    # Create a temporary directory with an empty roast/ subdirectory
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("roast")

        # Expect an exit since CLI::Kit aborts on error
        assert_raises(SystemExit) do
          capture_io do
            Roast::EntryPoint.call(["list"])
          end
        end
      end
    end
  end

  def test_list_with_workflows
    # Create a temporary directory with workflows
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        # Create various workflow structures
        FileUtils.mkdir_p("roast/workflow1")
        File.write("roast/workflow1/workflow.yml", "name: workflow1")

        FileUtils.mkdir_p("roast/workflow2")
        File.write("roast/workflow2/workflow.yml", "name: workflow2")

        FileUtils.mkdir_p("roast/nested/workflow3")
        File.write("roast/nested/workflow3/workflow.yml", "name: workflow3")

        # Root workflow
        File.write("roast/workflow.yml", "name: root")

        # Capture output using capture_io
        output, _err = capture_io do
          Roast::EntryPoint.call(["list"])
        end

        # Check the output contains expected workflows (order independent)
        assert_match(/Available workflows:/, output)
        assert_match(/\. \(from project\)/, output)
        assert_match(/workflow1 \(from project\)/, output)
        assert_match(/workflow2 \(from project\)/, output)
        assert_match(%r{nested/workflow3 \(from project\)}, output)
        assert_match(/Run a workflow with: roast execute <workflow_name>/, output)
      end
    end
  end

  test "execute with verbose mode re-raises errors with full backtrace" do
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")
      error_message = "Something went wrong!"

      # Mock the WorkflowRunner to raise an error
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).raises(StandardError.new(error_message))
      Roast::Workflow::WorkflowRunner.expects(:new).with(workflow_file, [], { executor: "default", verbose: true }).returns(mock_runner)

      # In verbose mode with CLI::Kit, the error should cause a system exit
      assert_raises(SystemExit) do
        capture_io do
          Roast::EntryPoint.call(["execute", "--verbose", workflow_file])
        end
      end
    end
  end

  test "execute without verbose mode only prints error message to stderr" do
    Dir.mktmpdir do |tmpdir|
      workflow_file = File.join(tmpdir, "workflow.yml")
      File.write(workflow_file, "name: test_workflow\nsteps: []")
      error_message = "Something went wrong!"

      # Mock the WorkflowRunner to raise an error
      mock_runner = mock("WorkflowRunner")
      mock_runner.expects(:begin!).raises(StandardError.new(error_message))
      Roast::Workflow::WorkflowRunner.expects(:new).with(workflow_file, [], { executor: "default" }).returns(mock_runner)

      # In non-verbose mode, the error should be printed to stderr but not cause exit in this case
      # because the Execute command catches and prints the error
      _out, err = capture_io do
        Roast::EntryPoint.call(["execute", workflow_file])
      end

      # The error message should be in stderr
      assert_match(error_message, err)
    end
  end

  test "version command outputs version" do
    output, _err = capture_io do
      Roast::EntryPoint.call(["version"])
    end

    assert_match(/Roast version #{Roast::VERSION}/, output)
  end

  test "help command shows usage" do
    output, _err = capture_io do
      Roast::EntryPoint.call(["--help"])
    end

    assert_match(/Roast - A framework for executing structured AI workflows/, output)
    assert_match(/Commands:/, output)
    assert_match(/execute/, output)
    assert_match(/version/, output)
  end
end
