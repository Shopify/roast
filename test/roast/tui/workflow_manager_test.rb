# typed: false
# frozen_string_literal: true

require "test_helper"
require "roast/tui/workflow_manager"

class WorkflowManagerTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir
    # Create a new manager for each test with a clean history
    Dir.chdir(@temp_dir) do
      @manager = Roast::TUI::WorkflowManager.new(@temp_dir)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  test "initializes with correct directory" do
    assert_equal File.expand_path(@temp_dir), @manager.current_directory
    # History might not be empty if there's a history file, but should be a hash
    assert_kind_of Hash, @manager.history
  end

  test "finds workflows in directory" do
    # Create a sample workflow file
    workflow_content = {
      "name" => "Test Workflow",
      "description" => "A test workflow",
      "steps" => ["Step 1", "Step 2"],
    }
    File.write(File.join(@temp_dir, "workflow.yml"), YAML.dump(workflow_content))

    workflows = @manager.list_workflows(recursive: false)
    assert_equal 1, workflows.size
    assert_equal "Test Workflow", workflows.first[:name]
    assert_equal "A test workflow", workflows.first[:description]
    assert_equal 2, workflows.first[:steps_count]
  end

  test "tracks workflow execution" do
    workflow_path = File.join(@temp_dir, "workflow.yml")
    
    @manager.track_execution(
      workflow_path,
      success: true,
      duration: 5.5,
    )

    history = @manager.history[workflow_path]
    assert_equal 1, history.size
    assert history.first[:success]
    assert_equal 5.5, history.first[:duration]
  end

  test "gets statistics for workflow" do
    workflow_path = File.join(@temp_dir, "workflow.yml")
    File.write(workflow_path, YAML.dump({ "name" => "Test" }))
    
    # Track some executions
    @manager.track_execution(workflow_path, success: true, duration: 5.0)
    @manager.track_execution(workflow_path, success: false, duration: 3.0)
    @manager.track_execution(workflow_path, success: true, duration: 4.0)
    
    stats = @manager.get_statistics(workflow_path)
    
    assert_equal 3, stats[:total_runs]
    assert_equal 2, stats[:successful]
    assert_equal 1, stats[:failed]
    assert_in_delta 66.7, stats[:success_rate], 0.1
    assert_equal 4.0, stats[:average_duration]
  end

  test "creates workflow from template" do
    Dir.chdir(@temp_dir) do
      # Mock user input
      ::CLI::UI.stub(:ask, "test_workflow") do
        ::CLI::UI.stub(:confirm, false) do
          filename = @manager.create_from_template("basic")
          
          assert_equal "test_workflow.yml", filename
          assert File.exist?(File.join(@temp_dir, filename))
          
          content = YAML.safe_load_file(File.join(@temp_dir, filename))
          assert_equal "My Workflow", content["name"]
          assert_includes content["tools"], "Roast::Tools::ReadFile"
        end
      end
    end
  end

  test "resolves workflow paths correctly" do
    Dir.chdir(@temp_dir) do
      workflow_path = File.join(@temp_dir, "test.yml")
      File.write(workflow_path, "")
      
      # Test various path resolution cases
      assert_equal workflow_path, @manager.send(:resolve_workflow_path, workflow_path)
      # The manager will find the file in current directory
      resolved_path = @manager.send(:resolve_workflow_path, "test")
      assert File.exist?(resolved_path)
      assert resolved_path.end_with?("test.yml")
      
      # Test non-existent file
      ::CLI::UI.stub(:fmt, ->(_) { "" }) do
        assert_nil @manager.send(:resolve_workflow_path, "nonexistent")
      end
    end
  end
end