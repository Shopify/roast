# frozen_string_literal: true

class FunctionalTest < ActiveSupport::TestCase
  def roast(*args)
    # debug=true allows us to capture error messages in tests
    Roast::CLI.start(args, { debug: true })
  end

  # Set up a roast directory structure.
  # with_workflow will create the workflow defined in Workflows.:name
  def in_sandbox(with_workflow: nil)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do |dir|
        Dir.mkdir('.roast')
        roastdir = File.join(dir, "roast")
        Dir.mkdir(roastdir)

        Dir.chdir(roastdir) do
          Workflows.build(with_workflow, roastdir) if with_workflow
        end

        yield
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

      def simple
        <<~YAML
          name: Simple workflow

          steps:
            - hello_world: "$(echo 'Hello world')"
        YAML
      end
    end
  end
end
