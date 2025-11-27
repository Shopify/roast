# frozen_string_literal: true

module DSL
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

    # Mock agent calls for testing without requiring real claude CLI
    def with_agent_mocks
      # Create a mock that simulates the claude CLI response for the simple_agent test
      mock_status = mock("Process::Status")
      mock_status.stubs(:success?).returns(true)
      mock_status.stubs(:signaled?).returns(false)

      # Mock the CommandRunner.execute method to simulate claude CLI response
      # Use a simple stub that catches all CommandRunner.execute calls
      original_execute = Roast::DSL::CommandRunner.method(:execute)

      Roast::DSL::CommandRunner.define_singleton_method(:execute) do |command_args, **options|
        if command_args.is_a?(Array) && command_args.first == "claude"
          # Simulate calling the stdout_handler with JSON response line
          json_response = "{\"type\":\"result\",\"session_id\":\"session-123\",\"result\":\"Caspian Sea sits,\\nThough called sea, it's landlocked, vast -\\nWorld's largest true lake.\",\"success\":true,\"duration_ms\":1500,\"num_turns\":1,\"modelUsage\":{\"claude-3-haiku-20240307\":{\"inputTokens\":15,\"outputTokens\":25,\"costUSD\":0.001}}}"

          options[:stdout_handler]&.call(json_response + "\n")

          [json_response + "\n", "", mock_status]
        else
          # Call the original method for non-claude commands
          original_execute.call(command_args, **options)
        end
      end

      yield

      # Restore original method after test
      Roast::DSL::CommandRunner.define_singleton_method(:execute, original_execute)
    end

    # Set up a temporary sandbox directory with all the examples
    # Parameter workflow_id is an arbitrary namespace/subdirectory within the sandbox
    # Returns an array of strings [stdio_output, stderr_output]
    def in_sandbox(workflow_id, &block)
      root_project_path = Dir.pwd
      project_dot_roast_path = File.join(root_project_path, ".roast")
      examples_source_path = File.join(root_project_path, "dsl")

      tmpdir_root = File.join(root_project_path, "tmp/sandboxes")
      tmpdir = nil

      FileUtils.mkdir_p(tmpdir_root) unless Dir.exist?(tmpdir_root)

      out, err = capture_io do
        in_tmpdir(workflow_id.to_s, tmpdir_root) do |workflow_dir|
          tmpdir = workflow_dir
          Dir.chdir(workflow_dir) do
            if Dir.exist?(project_dot_roast_path) && ENV["RECORD_VCR"]
              FileUtils.cp_r(project_dot_roast_path, ".roast")
            else
              Dir.mkdir(".roast")
              ENV["OPENAI_API_KEY"] = "dummy-key"
              ENV["OPENAI_API_BASE_URL"] = "http://mytestingproxy.local/v1"
            end

            FileUtils.cp_r("#{examples_source_path}/.", "dsl")
            Dir.chdir("dsl") do
              block.call
            end
          end
        end
      end

      path_regex = Regexp.new(tmpdir)
      out.gsub!(path_regex, "/fake-testing-dir")
      err.gsub!(path_regex, "/fake-testing-dir")

      if ENV["RECORD_VCR"] || ENV["DUMP_OUTPUT"]
        path = File.join(root_project_path, "tmp/results")
        puts "DSL Workflow result recorded with VCR in #{path}, use this for assertions."

        FileUtils.mkdir_p(path)
        File.write(File.join(path, "dsl-#{workflow_id}-stdout-dump"), out)
        File.write(File.join(path, "dsl-#{workflow_id}-stderr-dump"), err)
      end

      output_fixture_path = File.join("test", "fixtures", "dsl_output", "#{workflow_id}.txt")
      if File.exist?(output_fixture_path)
        assert_equal(File.read(output_fixture_path), out)
      end

      if ENV["CI"]
        puts "========= STDOUT ========="
        puts out
        puts "========= STDERR ========="
        puts err
        puts "========= ====== ========="
      end
      [out, err]
    end

    def in_tmpdir(prefix, tmpdir_root, &block)
      if ENV["PRESERVE_SANDBOX"]
        dir = Dir.mktmpdir(prefix, tmpdir_root)
        block.call(dir)
      else
        Dir.mktmpdir(prefix, tmpdir_root, &block)
      end
    end
  end
end
