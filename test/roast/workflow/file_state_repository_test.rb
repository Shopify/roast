# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class FileStateRepositoryTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @file = File.join(@temp_dir, "test.rb")
        @session_name = "test_workflow"
        @session_manager = SessionManager.new
        @repository = FileStateRepository.new(@session_manager)

        # Create test file and stub pwd
        FileUtils.touch(@file)
        Dir.stubs(:pwd).returns(@temp_dir)

        # Create a mock workflow
        @workflow = mock
        @workflow.stubs(
          file: @file,
          session_name: @session_name,
          session_timestamp: nil,
        )
        @workflow.stubs(:session_timestamp=)
      end

      def teardown
        FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
        Dir.unstub(:pwd)
      end

      test "#save_state creates directory structure and saves state" do
        state_data = {
          step_name: "test_step",
          order: 1,
          transcript: [],
          output: {},
          final_output: [],
          execution_order: ["test_step"],
        }

        @repository.save_state(@workflow, "test_step", state_data)

        # Verify directory structure
        workflow_dir = expected_workflow_dir
        assert File.directory?(workflow_dir)
        assert File.exist?(File.join(workflow_dir, ".gitignore"))

        session_dirs = Dir.children(workflow_dir).reject { |f| f == ".gitignore" }
        assert_equal 1, session_dirs.size

        session_dir = File.join(workflow_dir, session_dirs.first)
        state_files = Dir.glob(File.join(session_dir, "step_*_*.json"))
        assert_equal 1, state_files.size

        # Verify file content
        state = JSON.parse(File.read(state_files.first))
        assert_equal "test_step", state["step_name"]
        assert_equal 1, state["order"]
      end

      test "#save_state handles errors gracefully" do
        state_data = {
          step_name: "test_step",
          order: 1,
          transcript: [],
          output: {},
          final_output: [],
          execution_order: ["test_step"],
        }

        File.stubs(:write).raises(Errno::EACCES)

        output = capture_io do
          @repository.save_state(@workflow, "test_step", state_data)
        end

        assert_match(/Failed to save state/, output[1]) # stderr is at index 1
      end

      test "#save_state creates parent directories for nested steps" do
        state_data = {
          step_name: "test_nested/deeply/step",
          order: 1,
          transcript: [],
          output: {},
          final_output: [],
          execution_order: ["test_step"],
        }

        @repository.save_state(@workflow, state_data[:step_name], state_data)

        workflow_dir = expected_workflow_dir
        assert File.directory?(workflow_dir)

        session_dirs = Dir.children(workflow_dir).reject { |f| f == ".gitignore" }
        assert_equal 1, session_dirs.size

        session_dir = File.join(workflow_dir, session_dirs.first)
        state_paths = Dir.glob(File.join(session_dir, "step_*_*"))
        assert_equal 1, state_paths.size
        assert File.directory?(state_paths.first)

        state_file = File.join(state_paths.first, "deeply", "step.json")
        assert File.exist?(state_file)

        state = JSON.parse(File.read(state_file))
        assert_equal "test_nested/deeply/step", state["step_name"]
        assert_equal 1, state["order"]
      end

      test "#load_state_before_step returns false when no directory exists" do
        result = @repository.load_state_before_step(@workflow, "test_step")
        refute result
      end

      test "#load_state_before_step returns false when no sessions exist" do
        FileUtils.mkdir_p(expected_workflow_dir)
        result = @repository.load_state_before_step(@workflow, "test_step")
        refute result
      end

      test "#load_state_before_step returns false for the first step" do
        create_test_state("step1", 1)
        result = @repository.load_state_before_step(@workflow, "step1")
        refute result
      end

      test "#load_state_before_step returns false when step not found" do
        create_test_state("step1", 1)
        result = @repository.load_state_before_step(@workflow, "non_existent")
        refute result
      end

      test "#load_state_before_step loads previous state" do
        timestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S_%L")

        # Set a specific session timestamp
        @session_manager.set_session_timestamp(12345, timestamp)

        # Create a workflow with the specific timestamp
        workflow = mock
        workflow.stubs(
          file: @file,
          session_name: @session_name,
          session_timestamp: timestamp,
        )
        workflow.stubs(:session_timestamp=)

        # Create states in this session
        create_test_state_with_workflow(workflow, "step1", 1, user_data: "step1 data")
        create_test_state_with_workflow(workflow, "step2", 2, user_data: "step2 data")

        # Now load the state before step2, which should be step1
        result = @repository.load_state_before_step(workflow, "step2")
        assert result
        assert_equal "step1", result[:step_name]
        assert_equal "step1 data", result[:user_data]
      end

      test "#save_final_output creates a file with the output content" do
        result = @repository.save_final_output(@workflow, "Final output content")

        assert result
        assert File.exist?(result)
        assert_equal "Final output content", File.read(result)
        assert_match(/final_output\.txt$/, result)
      end

      test "#save_final_output returns nil for empty content" do
        result = @repository.save_final_output(@workflow, "")
        assert_nil result
      end

      test "#save_final_output handles errors gracefully" do
        File.stubs(:write).raises(Errno::EACCES)

        output = capture_io do
          @repository.save_final_output(@workflow, "content")
        end

        assert_match(/Failed to save final output/, output[1]) # stderr is at index 1
      end

      private

      def expected_workflow_dir
        workflow_dir_name = @workflow.session_name.parameterize.underscore
        file_id = Digest::MD5.hexdigest(@workflow.file)
        file_basename = File.basename(@workflow.file).parameterize.underscore
        human_readable_id = "#{file_basename}_#{file_id[0..7]}"
        File.join(@temp_dir, ".roast", "sessions", workflow_dir_name, human_readable_id)
      end

      def create_test_state(step_name, order, additional_data = {})
        state_data = {
          step_name: step_name,
          order: order,
          transcript: [],
          output: {},
          final_output: [],
          execution_order: [step_name],
        }.merge(additional_data)

        @repository.save_state(@workflow, step_name, state_data)
      end

      def create_test_state_with_workflow(workflow, step_name, order, additional_data = {})
        state_data = {
          step_name: step_name,
          order: order,
          transcript: [],
          output: {},
          final_output: [],
          execution_order: [step_name],
        }.merge(additional_data)

        @repository.save_state(workflow, step_name, state_data)
      end
    end
  end
end
