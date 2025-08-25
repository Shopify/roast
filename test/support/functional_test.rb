# frozen_string_literal: true

class FunctionalTest < ActiveSupport::TestCase
  def roast(*args)
    # debug=true allows us to capture error messages in tests
    Roast::CLI.start(args, { debug: true })
  end

  # Set up a roast directory structure.
  # with_workflow will create the workflow defined in Workflows.:name
  # Returns an array of strings [stdio_output, stderr_output]
  def in_sandbox(with_workflow: nil)
    # have to save our current working directory before entering sandbox
    candidate_example_path = File.join(Dir.pwd, "examples", with_workflow.to_s)

    capture_io do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do |dir|
          Dir.mkdir(".roast")
          workflow_directory = File.join(dir, "roast")
          Dir.mkdir(workflow_directory)

          Dir.chdir(workflow_directory) do
            if File.exist?(candidate_example_path)
              FileUtils.cp_r(candidate_example_path, with_workflow.to_s)
            else
              Workflows.build(with_workflow, workflow_directory)
            end
          end if with_workflow

          yield
        end
      end
    end
  end

  def assert_cli_error(match, &block)
    assert_raises(Thor::Error, match:, &block)
  end

  # Set up workflow files and paths
  class Workflows
    class << self
      def build(name, path)
        Dir.mkdir(name.to_s)
        File.write(File.join(path, name.to_s, "workflow.yml"), send(name))
      end

      private

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
