# frozen_string_literal: true

require "test_helper"

class RoastCLITest < ActiveSupport::TestCase
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
end
