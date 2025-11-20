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
            # Set up .roast directory for VCR or mock configuration
            if Dir.exist?(project_dot_roast_path) && ENV["RECORD_VCR"]
              FileUtils.cp_r(project_dot_roast_path, ".roast")
            else
              Dir.mkdir(".roast")
              # Configure Raix for legacy workflows
              Raix.configure do |config|
                config.openai_client = OpenAI::Client.new(
                  access_token: "dummy-key",
                  uri_base: "http://mytestingproxy.local",
                )
              end

              # Configure environment for DSL workflows
              ENV["OPENAI_API_KEY"] = "dummy-key"
              ENV["OPENAI_API_BASE_URL"] = "http://mytestingproxy.local/v1"
            end

            # Create dsl directory and copy files there for tests to find
            Dir.mkdir("dsl")
            Dir.glob("#{examples_source_path}/*").each do |file|
              if File.directory?(file)
                FileUtils.cp_r(file, File.join("dsl", File.basename(file)))
              else
                FileUtils.cp(file, File.join("dsl", File.basename(file)))
              end
            end
            block.call
          end
        end
      end

      # Replace random temp directory path with a standardized value (for easier assertions)
      path_regex = Regexp.new(tmpdir)
      out.gsub!(path_regex, "/fake-testing-dir")
      err.gsub!(path_regex, "/fake-testing-dir")

      # Record VCR output for debugging and fixture creation
      if ENV["RECORD_VCR"] || ENV["DUMP_OUTPUT"]
        path = File.join(root_project_path, "tmp/results")
        puts "DSL Workflow result recorded with VCR in #{path}, use this for assertions."

        FileUtils.mkdir_p(path)
        File.write(File.join(path, "dsl-#{workflow_id}-stdout-dump"), out)
        File.write(File.join(path, "dsl-#{workflow_id}-stderr-dump"), err)
      end

      # Check for output fixture and assert against it
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
