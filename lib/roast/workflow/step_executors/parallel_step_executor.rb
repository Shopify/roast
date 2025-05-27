# frozen_string_literal: true

require "roast/workflow/step_executors/base_step_executor"

module Roast
  module Workflow
    module StepExecutors
      class ParallelStepExecutor < BaseStepExecutor
        def execute(steps)
          # run steps in parallel, don't proceed until all are done
          threads = steps.map do |sub_step|
            Thread.new do
              # Each thread needs its own isolated execution context
              Thread.current[:step] = sub_step
              Thread.current[:result] = nil
              Thread.current[:error] = nil

              begin
                # Execute the single step in this thread
                workflow_executor.execute_steps([sub_step])
                Thread.current[:result] = :success
              rescue => e
                Thread.current[:error] = e
              end
            end
          end

          # Wait for all threads to complete
          threads.each(&:join)

          # Check for errors in any thread
          threads.each_with_index do |thread, _index|
            if thread[:error]
              raise thread[:error]
            end
          end

          :success
        end
      end
    end
  end
end
