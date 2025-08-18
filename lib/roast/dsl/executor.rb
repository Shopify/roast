# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class << self
        def from_file(workflow_path)
          execute(File.read(workflow_path))
        end

        private

        def execute(input)
          new.instance_eval(input)
        end
      end

      # Define methods to be used in workflows below.

      def shell(command_string)
        puts %x(#{command_string})
      end
    end
  end
end
