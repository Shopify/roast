# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

module Roast
  module Workflow
    class PrePostProcessingTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @workflow_path = File.join(@temp_dir, "workflow.yml")
        @pre_processing_dir = File.join(@temp_dir, "pre_processing")
        @post_processing_dir = File.join(@temp_dir, "post_processing")
        @steps_dir = @temp_dir

        FileUtils.mkdir_p(@pre_processing_dir)
        FileUtils.mkdir_p(@post_processing_dir)
      end

      def teardown
        FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      test "configuration loads pre_processing and post_processing steps" do
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          tools: []
          pre_processing:
            - setup_test_environment
            - gather_metrics
          steps:
            - process_file
          post_processing:
            - aggregate_results
            - generate_report
        YAML

        configuration = Configuration.new(@workflow_path)

        assert_equal ["setup_test_environment", "gather_metrics"], configuration.pre_processing
        assert_equal ["process_file"], configuration.steps
        assert_equal ["aggregate_results", "generate_report"], configuration.post_processing
      end

      test "step loader finds steps in pre_processing directory" do
        # Create a pre-processing step directory
        step_dir = File.join(@pre_processing_dir, "setup_test_environment")
        FileUtils.mkdir_p(step_dir)
        File.write(File.join(step_dir, "prompt.md"), "Setup the environment")

        # Create a mock workflow
        workflow = BaseWorkflow.new(nil, name: "test", context_path: @temp_dir)
        config_hash = { "name" => "test" }
        loader = StepLoader.new(workflow, config_hash, @temp_dir, phase: :pre_processing)

        step = loader.load("setup_test_environment")
        assert_instance_of BaseStep, step
        assert_equal "setup_test_environment", step.name
        assert_equal step_dir, step.context_path
      end

      test "step loader finds steps in post_processing directory" do
        # Create a post-processing step directory
        step_dir = File.join(@post_processing_dir, "generate_report")
        FileUtils.mkdir_p(step_dir)
        File.write(File.join(step_dir, "prompt.md"), "Generate report")

        # Create a mock workflow
        workflow = BaseWorkflow.new(nil, name: "test", context_path: @temp_dir)
        config_hash = { "name" => "test" }
        loader = StepLoader.new(workflow, config_hash, @temp_dir, phase: :post_processing)

        step = loader.load("generate_report")
        assert_instance_of BaseStep, step
        assert_equal "generate_report", step.name
        assert_equal step_dir, step.context_path
      end

      test "workflow runner executes pre-processing steps before main workflow" do
        # Create workflow configuration
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          tools: []
          pre_processing:
            - setup
          steps:
            - process
          post_processing:
            - cleanup
        YAML

        # Create step directories with prompts
        setup_dir = File.join(@pre_processing_dir, "setup")
        FileUtils.mkdir_p(setup_dir)
        File.write(File.join(setup_dir, "prompt.md"), "Setup step")

        process_dir = File.join(@steps_dir, "process")
        FileUtils.mkdir_p(process_dir)
        File.write(File.join(process_dir, "prompt.md"), "Process step")

        cleanup_dir = File.join(@post_processing_dir, "cleanup")
        FileUtils.mkdir_p(cleanup_dir)
        File.write(File.join(cleanup_dir, "prompt.md"), "Cleanup step")

        configuration = Configuration.new(@workflow_path)
        runner = WorkflowRunner.new(configuration)

        # Mock the workflow execution to track execution order
        execution_order = []

        runner.stub(:execute_workflow, ->(_workflow) { execution_order << :main_workflow }) do
          runner.stub(:run_pre_processing, -> { execution_order << :pre_processing }) do
            runner.stub(:run_post_processing, -> { execution_order << :post_processing }) do
              runner.run_targetless
            end
          end
        end

        assert_equal [:pre_processing, :main_workflow, :post_processing], execution_order
      end

      test "workflow runner executes workflows for each target file" do
        # Create workflow configuration
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          tools: []
          target: "#{File.join(@temp_dir, "*.txt")}"
          steps:
            - process
          post_processing:
            - aggregate
        YAML

        # Create test files
        File.write(File.join(@temp_dir, "file1.txt"), "content1")
        File.write(File.join(@temp_dir, "file2.txt"), "content2")

        # Create step directory with prompt to make workflow valid
        process_dir = File.join(@steps_dir, "process")
        FileUtils.mkdir_p(process_dir)
        File.write(File.join(process_dir, "prompt.md"), "Process the file")

        aggregate_dir = File.join(@post_processing_dir, "aggregate")
        FileUtils.mkdir_p(aggregate_dir)
        File.write(File.join(aggregate_dir, "prompt.md"), "Aggregate results")

        configuration = Configuration.new(@workflow_path)
        runner = WorkflowRunner.new(configuration)

        # Track execution by stubbing the workflow executor
        executed_files = []

        WorkflowExecutor.stub(:new, ->(workflow, _config_hash, _context_path, **options) {
          # Only track main workflow executions (not pre/post processing)
          if options[:phase].nil?
            executed_files << workflow.file
          end
          # Return a mock executor that does nothing
          mock_executor = mock("executor")
          mock_executor.stubs(:execute_steps)
          mock_executor
        }) do
          runner.run_for_targets
        end

        # Verify workflows were executed for each file
        assert_equal 2, executed_files.length
        assert_includes executed_files, File.join(@temp_dir, "file1.txt")
        assert_includes executed_files, File.join(@temp_dir, "file2.txt")
      end

      test "workflow executor creates correct phase-specific loader" do
        workflow = BaseWorkflow.new(nil, name: "test", context_path: @temp_dir)
        config_hash = { "name" => "test" }

        # Test default phase
        executor = WorkflowExecutor.new(workflow, config_hash, @temp_dir)
        assert_equal :steps, executor.step_loader.phase

        # Test pre-processing phase
        pre_executor = WorkflowExecutor.new(workflow, config_hash, @temp_dir, phase: :pre_processing)
        assert_equal :pre_processing, pre_executor.step_loader.phase

        # Test post-processing phase
        post_executor = WorkflowExecutor.new(workflow, config_hash, @temp_dir, phase: :post_processing)
        assert_equal :post_processing, post_executor.step_loader.phase
      end

      test "post-processing applies output.txt template when present" do
        # Create workflow configuration with post-processing
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          tools: []
          target: "#{File.join(@temp_dir, "test.txt")}"
          steps:
            - process
          post_processing:
            - finalize
        YAML

        # Create test file
        File.write(File.join(@temp_dir, "test.txt"), "test content")

        # Create step directory
        process_dir = File.join(@steps_dir, "process")
        FileUtils.mkdir_p(process_dir)
        File.write(File.join(process_dir, "prompt.md"), "Process the file")

        # Create post-processing step
        finalize_dir = File.join(@post_processing_dir, "finalize")
        FileUtils.mkdir_p(finalize_dir)
        File.write(File.join(finalize_dir, "prompt.md"), "Finalize results")

        # Create output.txt template in post_processing directory
        File.write(File.join(@post_processing_dir, "output.txt"), <<~ERB)
          === Post-Processing Summary ===
          <% if defined?(targets) && targets %>
          Processed <%= targets.size %> file(s)
          <% end %>

          <% if defined?(output) && output["finalize"] %>
          Finalization output: <%= output["finalize"] %>
          <% end %>
          ==============================
        ERB

        configuration = Configuration.new(@workflow_path)
        runner = WorkflowRunner.new(configuration)

        # Mock the workflow execution
        WorkflowExecutor.stub(:new, ->(workflow, _config_hash, _context_path, **options) {
          mock_executor = mock("executor")
          mock_executor.stubs(:execute_steps)

          # Simulate post-processing step output
          if options[:phase] == :post_processing
            workflow.output_manager.output["finalize"] = "All tasks completed"
          end

          mock_executor
        }) do
          output = capture_io { runner.run_for_targets }

          # Check that the template was applied
          assert_match(/=== Post-Processing Summary ===/, output[0])
          assert_match(/Processed 1 file\(s\)/, output[0])
          assert_match(/Finalization output: All tasks completed/, output[0])
        end
      end

      test "single-target workflows support pre and post processing" do
        # Create workflow configuration with single target
        File.write(@workflow_path, <<~YAML)
          name: single_target_workflow
          tools: []
          target: "#{File.join(@temp_dir, "single_file.txt")}"
          pre_processing:
            - prepare
          steps:
            - analyze
          post_processing:
            - report
        YAML

        # Create target file
        File.write(File.join(@temp_dir, "single_file.txt"), "content")

        # Create step directories
        prepare_dir = File.join(@pre_processing_dir, "prepare")
        FileUtils.mkdir_p(prepare_dir)
        File.write(File.join(prepare_dir, "prompt.md"), "Prepare environment")

        analyze_dir = File.join(@steps_dir, "analyze")
        FileUtils.mkdir_p(analyze_dir)
        File.write(File.join(analyze_dir, "prompt.md"), "Analyze file")

        report_dir = File.join(@post_processing_dir, "report")
        FileUtils.mkdir_p(report_dir)
        File.write(File.join(report_dir, "prompt.md"), "Generate report")

        configuration = Configuration.new(@workflow_path)
        runner = WorkflowRunner.new(configuration)

        # Track execution order
        execution_phases = []

        WorkflowExecutor.stub(:new, ->(_workflow, _config_hash, _context_path, **options) {
          execution_phases << options[:phase]
          mock_executor = mock("executor")
          mock_executor.stubs(:execute_steps)
          mock_executor
        }) do
          output = capture_io { runner.run_for_targets }

          # Verify all phases were executed in order
          assert_equal 3, execution_phases.size
          assert_equal :pre_processing, execution_phases[0]
          assert_nil execution_phases[1] # Main workflow has no phase
          assert_equal :post_processing, execution_phases[2]

          # Verify output messages
          assert_match(/Running pre-processing steps/, output[1])
          assert_match(/Running workflow for file/, output[1])
          assert_match(/Running post-processing steps/, output[1])
        end
      end

      test "step loader finds step in per-step path directory (relative path)" do
        # Create a custom directory for a specific step, relative to workflow
        per_step_dir = File.join(@temp_dir, "per_step_relative")
        FileUtils.mkdir_p(File.join(per_step_dir, "rel_step"))
        File.write(File.join(per_step_dir, "rel_step", "prompt.md"), "Relative path prompt")

        # Write workflow YAML with per-step relative path
        rel_path = File.basename(per_step_dir) # relative to workflow
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          steps:
            - rel_step
          rel_step:
            path: #{rel_path}
        YAML

        configuration = Configuration.new(@workflow_path)
        loader = StepLoader.new(BaseWorkflow.new(nil, name: "test", context_path: @temp_dir), configuration.config_hash, @temp_dir)
        step = loader.load("rel_step")
        assert_instance_of BaseStep, step
        assert_equal "rel_step", step.name
        assert_equal File.join(per_step_dir, "rel_step"), step.context_path
      end

      test "step loader finds step in per-step path directory (absolute path)" do
        # Create a custom directory for a specific step, absolute path
        per_step_dir = File.join(@temp_dir, "per_step_absolute")
        FileUtils.mkdir_p(File.join(per_step_dir, "abs_step"))
        File.write(File.join(per_step_dir, "abs_step", "prompt.md"), "Absolute path prompt")

        # Write workflow YAML with per-step absolute path
        abs_path = per_step_dir # already absolute
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          steps:
            - abs_step
          abs_step:
            path: #{abs_path}
        YAML

        configuration = Configuration.new(@workflow_path)
        loader = StepLoader.new(BaseWorkflow.new(nil, name: "test", context_path: @temp_dir), configuration.config_hash, @temp_dir)
        step = loader.load("abs_step")
        assert_instance_of BaseStep, step
        assert_equal "abs_step", step.name
        assert_equal File.join(per_step_dir, "abs_step"), step.context_path
      end

      test "step loader finds multiple steps each with a different path" do
        # Create two custom directories for two steps
        rel_dir = File.join(@temp_dir, "multi_rel")
        abs_dir = File.join(@temp_dir, "multi_abs")
        FileUtils.mkdir_p(File.join(rel_dir, "step_a"))
        FileUtils.mkdir_p(File.join(abs_dir, "step_b"))
        File.write(File.join(rel_dir, "step_a", "prompt.md"), "Prompt for step A (relative)")
        File.write(File.join(abs_dir, "step_b", "prompt.md"), "Prompt for step B (absolute)")

        # Write workflow YAML with both steps, one relative, one absolute
        rel_path = File.basename(rel_dir)
        abs_path = abs_dir
        File.write(@workflow_path, <<~YAML)
          name: test_workflow
          steps:
            - step_a
            - step_b
          step_a:
            path: #{rel_path}
          step_b:
            path: #{abs_path}
        YAML

        configuration = Configuration.new(@workflow_path)
        loader = StepLoader.new(BaseWorkflow.new(nil, name: "test", context_path: @temp_dir), configuration.config_hash, @temp_dir)
        step_a = loader.load("step_a")
        step_b = loader.load("step_b")
        assert_instance_of BaseStep, step_a
        assert_instance_of BaseStep, step_b
        assert_equal "step_a", step_a.name
        assert_equal "step_b", step_b.name
        assert_equal File.join(rel_dir, "step_a"), step_a.context_path
        assert_equal File.join(abs_dir, "step_b"), step_b.context_path
      end
    end
  end
end
