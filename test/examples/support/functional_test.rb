# frozen_string_literal: true

module Examples
  class FunctionalTest < ActiveSupport::TestCase
    # Set up a temporary sandbox directory with all the examples
    # Parameter workflow_id is an arbitrary namespace/subdirectory within the sandbox
    # Returns an array of strings [stdio_output, stderr_output]
    def in_sandbox(workflow_id, &block)
      root_project_path = Dir.pwd
      examples_source_path = File.join(root_project_path, "examples")

      tmpdir_root = File.join(root_project_path, "tmp/sandboxes")
      tmpdir = nil

      FileUtils.mkdir_p(tmpdir_root) unless Dir.exist?(tmpdir_root)

      out, err = capture_io do
        # Set up test environment variables for VCR playback
        # When recording (RECORD_VCR=true), uses real credentials from environment
        # When playing back, uses fake credentials (VCR intercepts all requests)
        recording = ENV["RECORD_VCR"]

        with_env("OPENAI_API_KEY", recording ? ENV["OPENAI_API_KEY"] : "my-token") do
          with_env("OPENAI_API_BASE", recording ? ENV["OPENAI_API_BASE"] : "http://mytestingproxy.local/v1") do
            in_tmpdir(workflow_id.to_s, tmpdir_root) do |workflow_dir|
              tmpdir = workflow_dir
              FileUtils.cp_r(examples_source_path, workflow_dir)

              VCR.use_cassette(workflow_id.to_s, record: recording ? :all : :none) do
                block.call
              end
            end
          end
        end
      end

      # Replace random temp directory path with a standardized value (for easier assertions)
      path_regex = Regexp.new(tmpdir)
      out.gsub!(path_regex, "/fake-testing-dir")
      err.gsub!(path_regex, "/fake-testing-dir")

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
