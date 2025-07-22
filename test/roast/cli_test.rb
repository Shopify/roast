# frozen_string_literal: true

require "test_helper"

class RoastCLITest < ActiveSupport::TestCase
  def setup
    super
    # Prevent XDG migration from running during CLI tests since they call cli.execute()
    # Note: XDG migration now only shows warnings, not automatic migration
    # Also stub warn_if_migration_needed to prevent warnings during tests
    Roast::XDGMigration.stubs(:warn_if_migration_needed)
  end

  def test_execute_with_workflow_yml_path
    workflow_path = "path/to/workflow.yml"
    expanded_path = File.expand_path(workflow_path)

    # Mock the ConfigurationParser to prevent actual execution
    mock_parser = mock("ConfigurationParser")
    mock_parser.expects(:begin!).once
    Roast::Workflow::ConfigurationParser.expects(:new).with(expanded_path, [], {}).returns(mock_parser)

    # Make sure File.directory? returns false to avoid the directory error
    File.expects(:directory?).with(expanded_path).returns(false)

    # Execute the CLI command
    cli = Roast::CLI.new
    cli.execute(workflow_path)
  end

  def test_execute_with_conventional_path
    workflow_name = "my_workflow"
    conventional_path = "roast/#{workflow_name}/workflow.yml"
    expanded_path = File.expand_path(conventional_path)

    # Mock the ConfigurationParser to prevent actual execution
    mock_parser = mock("ConfigurationParser")
    mock_parser.expects(:begin!).once
    Roast::Workflow::ConfigurationParser.expects(:new).with(expanded_path, [], {}).returns(mock_parser)

    # Make sure File.directory? returns false to avoid the directory error
    File.expects(:directory?).with(expanded_path).returns(false)

    # Execute the CLI command
    cli = Roast::CLI.new
    cli.execute(workflow_name)
  end

  def test_execute_with_directory_path_raises_error
    workflow_path = "path/to/directory"
    expanded_path = File.expand_path("roast/#{workflow_path}/workflow.yml")

    # Make the directory check return true to trigger the error
    File.expects(:directory?).with(expanded_path).returns(true)

    # Execute the CLI command and expect an error
    cli = Roast::CLI.new
    assert_raises(Thor::Error) do
      cli.execute(workflow_path)
    end
  end

  def test_execute_with_files_passes_files_to_parser
    workflow_path = "path/to/workflow.yml"
    expanded_path = File.expand_path(workflow_path)
    files = ["file1.rb", "file2.rb"]

    # Mock the ConfigurationParser to prevent actual execution
    mock_parser = mock("ConfigurationParser")
    mock_parser.expects(:begin!).once
    Roast::Workflow::ConfigurationParser.expects(:new).with(expanded_path, files, {}).returns(mock_parser)

    # Make sure File.directory? returns false to avoid the directory error
    File.expects(:directory?).with(expanded_path).returns(false)

    # Execute the CLI command
    cli = Roast::CLI.new
    cli.execute(workflow_path, *files)
  end

  def test_execute_with_options_passes_options_to_parser
    workflow_path = "path/to/workflow.yml"
    expanded_path = File.expand_path(workflow_path)
    options = { "verbose" => true, "concise" => false }

    # Mock the ConfigurationParser to prevent actual execution
    mock_parser = mock("ConfigurationParser")
    mock_parser.expects(:begin!).once
    Roast::Workflow::ConfigurationParser.expects(:new).with(expanded_path, [], options.transform_keys(&:to_sym)).returns(mock_parser)

    # Make sure File.directory? returns false to avoid the directory error
    File.expects(:directory?).with(expanded_path).returns(false)

    # Create CLI with options
    cli = Roast::CLI.new([], options)
    cli.execute(workflow_path)
  end

  def test_list_with_no_roast_directory
    # Create a temporary directory without a roast/ subdirectory
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        cli = Roast::CLI.new

        # Expect the error message
        assert_raises(Thor::Error, "No roast/ directory found in current path") do
          cli.list
        end
      end
    end
  end

  def test_list_with_empty_roast_directory
    # Create a temporary directory with an empty roast/ subdirectory
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("roast")

        cli = Roast::CLI.new

        # Expect the error message
        assert_raises(Thor::Error, "No workflow.yml files found in roast/ directory") do
          cli.list
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

        cli = Roast::CLI.new

        # Capture output using capture_io
        output, _err = capture_io do
          cli.list
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
end
