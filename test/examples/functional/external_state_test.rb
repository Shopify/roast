# frozen_string_literal: true

require "test_helper"

module Examples::Functional
  class ExternalStateTest < ActiveSupport::TestCase
    setup do
      Roast::EventMonitor.reset!
    end

    teardown do
      Roast::EventMonitor.reset!
    end

    test "selected state survives independent workflow runs" do
      Dir.mktmpdir do |dir|
        with_env("ROAST_STATE_FILE", File.join(dir, "state.json")) do
          with_env("ROAST_STATE_ACTION", "save") do
            assert_equal({ "status" => "saved" }, run_example)
          end
          with_env("ROAST_STATE_ACTION", "recall") do
            assert_equal(
              { "status" => "found", "value" => { "checklist" => "Run the synthetic smoke check before packaging." } },
              run_example,
            )
          end
        end
      end
    end

    test "a missing file abstains and malformed state fails" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "state.json")
        with_env("ROAST_STATE_FILE", path) do
          with_env("ROAST_STATE_ACTION", "recall") do
            assert_equal({ "status" => "abstain" }, run_example)
            File.write(path, "invalid JSON")
            assert_raises(JSON::ParserError) do
            capture_io do
              Roast::Workflow.from_file("examples/external_state.rb", Roast::WorkflowParams.new([], [], {}))
            end
          end
          end
        end
      end
    end

    private

    def run_example
      before = @logger_output.string.length
      capture_io do
        Roast::Workflow.from_file("examples/external_state.rb", Roast::WorkflowParams.new([], [], {}))
      end
      stdout, = original_streams_from_logger_output(logger_output: @logger_output.string[before..])
      JSON.parse(stdout)
    end
  end
end
