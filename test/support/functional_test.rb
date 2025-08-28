# frozen_string_literal: true

class FunctionalTest < ActiveSupport::TestCase
  setup do
    Thread.current[:chat_completion_response] = nil
    Thread.current[:current_step_name] = nil
    Thread.current[:workflow_metadata] = nil
    Thread.current[:workflow_context] = nil
    Thread.current[:step] = nil
    Thread.current[:result] = nil
    Thread.current[:error] = nil
    Roast::Helpers::Logger.reset
  end

  def roast(*args)
    # debug=true allows us to capture error messages in tests
    Roast::CLI.start(args, { debug: true })
  end

  # Set up a roast directory structure.
  # with_workflow will create the workflow defined in Workflows.:name
  # Returns an array of strings [stdio_output, stderr_output]
  def in_sandbox(with_workflow: nil, with_sample_data: [], &block)
    with_sample_data = Array.wrap(with_sample_data)
    # have to save our current working directory before entering sandbox
    root_project_path = Dir.pwd
    project_dot_roast_path = File.join(root_project_path, ".roast")
    candidate_example_path = File.join(root_project_path, "examples", with_workflow.to_s)
    fixture_source_path = File.join(root_project_path, "test", "fixtures", "sample_data")

    tmpdir_root = File.join(root_project_path, "tmp/sandboxes")
    tmpdir = nil

    FileUtils.mkdir_p(tmpdir_root) unless Dir.exist?(tmpdir_root)

    out, err = capture_io do
      Dir.mktmpdir(nil, tmpdir_root) do |dir|
        tmpdir = dir
        Dir.chdir(dir) do |dir|
          if Dir.exist?(project_dot_roast_path) && ENV["RECORD_VCR"]
            FileUtils.cp_r(project_dot_roast_path, ".roast")
          else
            Dir.mkdir(".roast")
            Raix.configure do |config|
              config.openai_client = OpenAI::Client.new(
                access_token: "dummy-key",
                uri_base: "http://mytestingproxy.local",
              )
            end
          end

          workflow_directory = File.join(dir, "roast")
          Dir.mkdir(workflow_directory)

          Dir.chdir(workflow_directory) do
            with_sample_data.each { |file| FileUtils.cp(File.join(fixture_source_path, file), file) }
            if File.exist?(candidate_example_path)
              FileUtils.cp_r(candidate_example_path, with_workflow.to_s)
            else
              Workflows.build(with_workflow, workflow_directory)
            end
          end if with_workflow

          block.call
        end
      end
    end

    # Normalize sandbox path
    path_regex = Regexp.new(tmpdir)
    out.gsub!(path_regex, "/fake-testing-dir")
    err.gsub!(path_regex, "/fake-testing-dir")

    if ENV["PRINT_OUTPUT"]
      puts out
    end

    [out, err]
  end

  def assert_cli_error(match, &block)
    assert_raises(Thor::Error, match:, &block)
  end

  def assert_from_sandbox(expected_output: nil, expected_error: nil, with_workflow: nil, with_sample_data: [], &block)
    out, err = in_sandbox(with_workflow: with_workflow, with_sample_data: with_sample_data, &block)
    assert_equal(expected_output&.squish, out.squish) unless expected_output.nil?
    assert_equal(expected_error&.squish, err.squish) unless expected_error.nil?
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
