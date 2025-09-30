# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class ExecutorError < Roast::Error ; end
      class ExecutorAlreadyPreparedError < ExecutorError ; end
      class ExecutorAlreadyCompletedError < ExecutorError ; end

      class << self
        def from_file(workflow_path)
          run!(File.read(workflow_path))
        end

        private

        def run!(input)
          executor = new
          executor.prepare!(input)
          executor.start!
        end
      end

      def prepare!(input)
        # You can only initialize an executor once.
        raise ExecutorAlreadyPreparedError if @prepared
        instance_eval(input)
        @prepared = true
      end

      def config
        # Do any initial cog setup
        yield
      end

      def execute
        # Move the cogs into the roast state machine
        yield
      end

      def start!
        # Now we run the cogs!
        # You can only do this once, executors are not reusable to avoid state pollution
        raise ExecutorAlreadyCompletedError if @completed
      end

      def shell(command_string)
        output, _status = Roast::Helpers::CmdRunner.capture2e(command_string)
        puts output
      end
    end
  end
end
