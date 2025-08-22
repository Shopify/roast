# frozen_string_literal: true

class FunctionalTest < ActiveSupport::TestCase
  def roast(*args)
    # Use the new CLI::Kit entry point
    Roast::EntryPoint.call(args)
  end

  # Set up a roast directory structure.
  # with_workflow will create the workflow defined in Workflows.:name
  # Returns an array of strings [stdio_output, stderr_output]
  def in_sandbox(with_workflow: nil)
    capture_io do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do |dir|
          Dir.mkdir(".roast")
          roastdir = File.join(dir, "roast")
          Dir.mkdir(roastdir)

          Dir.chdir(roastdir) do
            Workflows.build(with_workflow, roastdir) if with_workflow
          end

          yield
        end
      end
    end
  end

  def assert_cli_error(match, &block)
    assert_raises(Roast::Abort, match:, &block)
  end

  # Set up workflow files and paths
  class Workflows
    class << self
      def build(name, path)
        Dir.mkdir(name.to_s)
        File.write(File.join(path, name.to_s, "workflow.yml"), send(name))
      end

      def simple
        <<~YAML
          name: Simple workflow

          steps:
            - hello_world: >
                $(echo 'Hello world! I am roast!' > step_output.txt)

          hello_world:
            print_response: true
        YAML
      end
    end
  end
end
