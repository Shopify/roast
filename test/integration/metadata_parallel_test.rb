# frozen_string_literal: true

require "test_helper"

class MetadataParallelTest < ActiveSupport::TestCase
  test "metadata thread locals are set during parallel execution" do
    Dir.mktmpdir do |tmpdir|
      # Create simple steps that track thread information
      before_step = <<~RUBY
        class BeforeStep < Roast::Workflow::BaseStep
          include Roast::Helpers::MetadataAccess

          def call
            set_current_step_metadata("thread_id", Thread.current.object_id)
            set_current_step_metadata("timestamp", Time.now.to_f)
            "Before step completed"
          end
        end
      RUBY

      parallel_a_step = <<~RUBY
        class ParallelAStep < Roast::Workflow::BaseStep
          include Roast::Helpers::MetadataAccess

          def call
            set_current_step_metadata("thread_id", Thread.current.object_id)
            set_current_step_metadata("timestamp", Time.now.to_f)
            sleep(0.01) # Small delay to simulate execution
            set_current_step_metadata("step_description", "Parallel A")
            "Parallel A completed"
          end
        end
      RUBY

      parallel_b_step = <<~RUBY
        class ParallelBStep < Roast::Workflow::BaseStep
          include Roast::Helpers::MetadataAccess

          def call
            set_current_step_metadata("thread_id", Thread.current.object_id)
            set_current_step_metadata("timestamp", Time.now.to_f)
            sleep(0.01) # Small delay to simulate execution
            set_current_step_metadata("step_description", "Parallel B")
            "Parallel B completed"
          end
        end
      RUBY

      after_step = <<~RUBY
        class AfterStep < Roast::Workflow::BaseStep
          include Roast::Helpers::MetadataAccess

          def call
            set_current_step_metadata("thread_id", Thread.current.object_id)
            set_current_step_metadata("timestamp", Time.now.to_f)

            # Try to access metadata from previous steps
            before_thread = workflow_metadata&.dig("before_step", "thread_id")
            parallel_a_thread = workflow_metadata&.dig("parallel_a_step", "thread_id")
            parallel_b_thread = workflow_metadata&.dig("parallel_b_step", "thread_id")
            parallel_a_descr = workflow_metadata&.dig("parallel_a_step", "step_description")
            parallel_b_descr = workflow_metadata&.dig("parallel_b_step", "step_description")

            set_current_step_metadata("saw_before_thread", before_thread)
            set_current_step_metadata("saw_parallel_a_thread", parallel_a_thread)
            set_current_step_metadata("saw_parallel_b_thread", parallel_b_thread)
            set_current_step_metadata("saw_parallel_a_descr", parallel_a_descr)
            set_current_step_metadata("saw_parallel_b_descr", parallel_b_descr)

            "After step completed"
          end
        end
      RUBY

      # Write step files
      File.write(File.join(tmpdir, "before_step.rb"), before_step)
      File.write(File.join(tmpdir, "parallel_a_step.rb"), parallel_a_step)
      File.write(File.join(tmpdir, "parallel_b_step.rb"), parallel_b_step)
      File.write(File.join(tmpdir, "after_step.rb"), after_step)

      workflow_config = {
        "steps" => [
          "before_step",
          [
            "parallel_a_step",
            "parallel_b_step",
          ],
          "after_step",
        ],
      }

      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, workflow_config.to_yaml)

      workflow = Roast::Workflow::BaseWorkflow.new(workflow_file)
      executor = Roast::Workflow::WorkflowExecutor.new(workflow, workflow_config, tmpdir)
      executor.execute_steps(workflow_config["steps"])

      # Verify all steps executed
      assert_equal "Before step completed", workflow.output["before_step"]
      assert_equal "Parallel A completed", workflow.output["parallel_a_step"]
      assert_equal "Parallel B completed", workflow.output["parallel_b_step"]
      assert_equal "After step completed", workflow.output["after_step"]

      # Verify metadata was written by all steps
      assert workflow.metadata.before_step.thread_id
      assert workflow.metadata.parallel_a_step.thread_id
      assert workflow.metadata.parallel_b_step.thread_id
      assert workflow.metadata.after_step.thread_id

      # Verify parallel steps ran in different threads
      before_thread = workflow.metadata.before_step.thread_id
      parallel_a_thread = workflow.metadata.parallel_a_step.thread_id
      parallel_b_thread = workflow.metadata.parallel_b_step.thread_id
      after_thread = workflow.metadata.after_step.thread_id

      assert_not_equal parallel_a_thread, parallel_b_thread, "Parallel steps should run in different threads"
      assert_equal before_thread, after_thread, "Sequential steps should run in the same thread"

      # Verify the after step could see metadata from all previous steps
      assert_equal before_thread, workflow.metadata.after_step.saw_before_thread
      assert_equal parallel_a_thread, workflow.metadata.after_step.saw_parallel_a_thread
      assert_equal parallel_b_thread, workflow.metadata.after_step.saw_parallel_b_thread
      assert_equal workflow.metadata.parallel_a_step.step_description, workflow.metadata.after_step.saw_parallel_a_descr
      assert_equal workflow.metadata.parallel_b_step.step_description, workflow.metadata.after_step.saw_parallel_b_descr
    end
  end

  test "metadata access during parallel execution is thread-safe" do
    Dir.mktmpdir do |tmpdir|
      # Create a step that writes lots of metadata
      writer_step = <<~RUBY
        class MetadataStressTest < Roast::Workflow::BaseStep
          include Roast::Helpers::MetadataAccess

          def call
            step_id = self.class.name + "_" + Thread.current.object_id.to_s

            # Write multiple metadata entries rapidly
            100.times do |i|
              set_current_step_metadata("entry_\#{i}", "\#{step_id}_value_\#{i}")
            end

            # Verify our own writes
            100.times do |i|
              value = workflow_metadata&.dig(current_step_name, "entry_\#{i}")
              unless value == "\#{step_id}_value_\#{i}"
                set_current_step_metadata("error", "Metadata corruption detected at entry_\#{i}")
                break
              end
            end

            set_current_step_metadata("completed", true)
            "Stress test completed"
          end
        end
      RUBY

      File.write(File.join(tmpdir, "metadata_stress_test.rb"), writer_step)

      workflow_config = {
        "steps" => [
          [
            "metadata_stress_test",
            "metadata_stress_test",
            "metadata_stress_test",
            "metadata_stress_test",
          ],
        ],
      }

      workflow_file = File.join(tmpdir, "test_workflow.yml")
      File.write(workflow_file, workflow_config.to_yaml)

      workflow = Roast::Workflow::BaseWorkflow.new(workflow_file)
      executor = Roast::Workflow::WorkflowExecutor.new(workflow, workflow_config, tmpdir)
      executor.execute_steps(workflow_config["steps"])

      # Verify metadata has one step entry and it is self-consistent
      metadata = workflow.metadata
      assert_equal 1, metadata.keys.length, "Metadata only has one step entry (all steps had same name)"
      assert metadata.dig("metadata_stress_test", "completed"), "Step should have completed"
      assert_nil metadata.dig("metadata_stress_test", "error"),
        "No metadata corruption should be detected (writes all came from same step instance)"
    end
  end
end
