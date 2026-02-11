# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class OpencodeTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
          end

          test "provider is registered as :opencode" do
            assert Provider.registered?(:opencode)
            assert_equal Opencode, Provider.resolve(:opencode)
          end

          test "provider is not the default" do
            assert_equal :claude, Provider.default_provider_name
          end

          test "invoke creates an invocation, runs it, and wraps the result" do
            @config.provider(:opencode)
            provider = Opencode.new(@config)

            input = Agent::Input.new
            input.prompt = "test prompt"

            mock_result = Opencode::OpencodeInvocation::Result.new
            mock_result.response = "test response"
            mock_result.success = true

            mock_invocation = mock
            mock_invocation.expects(:run!)
            mock_invocation.expects(:result).returns(mock_result)

            Opencode::OpencodeInvocation.expects(:new).with(@config, input).returns(mock_invocation)

            output = provider.invoke(input)
            assert_equal "test response", output.response
          end
        end

        class OpencodeInvocationCommandLineTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
            @input = Agent::Input.new
            @input.prompt = "hello world"
          end

          test "default command uses opencode binary" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_equal "opencode", cmd.first
          end

          test "command includes run subcommand" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_includes cmd, "run"
          end

          test "command includes --format json" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            format_index = cmd.index("--format")
            assert format_index, "expected --format flag"
            assert_equal "json", cmd[format_index + 1]
          end

          test "prompt is the last argument" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_equal "hello world", cmd.last
          end

          test "custom model is included" do
            @config.model("gemini-2.5-pro")
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            model_index = cmd.index("--model")
            assert model_index, "expected --model flag"
            assert_equal "gemini-2.5-pro", cmd[model_index + 1]
          end

          test "custom command as string" do
            @config.command("/usr/local/bin/opencode")
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_equal "/usr/local/bin/opencode", cmd.first
          end

          test "custom command as array" do
            @config.command(["my-opencode", "--some-flag"])
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_equal "my-opencode", cmd[0]
            assert_equal "--some-flag", cmd[1]
          end

          test "run subcommand is not duplicated when already in custom command" do
            @config.command(["opencode", "run"])
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            assert_equal 1, cmd.count("run")
          end

          test "session flags are included when session is present" do
            @input.session = "ses_abc123"
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            session_index = cmd.index("--session")
            assert session_index, "expected --session flag"
            assert_equal "ses_abc123", cmd[session_index + 1]
            assert_includes cmd, "--fork"
          end

          test "session flags are not included when session is nil" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            cmd = invocation.send(:command_line)

            refute_includes cmd, "--session"
            refute_includes cmd, "--fork"
          end
        end

        class OpencodeInvocationStateTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
            @input = Agent::Input.new
            @input.prompt = "test"
          end

          test "result raises OpencodeNotStartedError when not started" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)

            assert_raises(Opencode::OpencodeInvocation::OpencodeNotStartedError) do
              invocation.result
            end
          end

          test "run! raises OpencodeAlreadyStartedError when already started" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            invocation.instance_variable_set(:@started, true)

            assert_raises(Opencode::OpencodeInvocation::OpencodeAlreadyStartedError) do
              invocation.run!
            end
          end

          test "result raises OpencodeFailedError when invocation failed" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            invocation.instance_variable_set(:@started, true)
            invocation.instance_variable_set(:@failed, true)

            assert_raises(Opencode::OpencodeInvocation::OpencodeFailedError) do
              invocation.result
            end
          end

          test "result raises OpencodeNotCompletedError when still running" do
            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            invocation.instance_variable_set(:@started, true)

            assert_raises(Opencode::OpencodeInvocation::OpencodeNotCompletedError) do
              invocation.result
            end
          end
        end

        class OpencodeInvocationEventHandlingTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
            @input = Agent::Input.new
            @input.prompt = "test"
            @invocation = Opencode::OpencodeInvocation.new(@config, @input)
          end

          test "handle_stdout parses text events and accumulates response" do
            @invocation.send(:handle_stdout, '{"type":"text","sessionID":"ses_1","part":{"text":"Hello "}}')
            @invocation.send(:handle_stdout, '{"type":"text","sessionID":"ses_1","part":{"text":"world"}}')

            result = @invocation.instance_variable_get(:@result)
            assert_equal "Hello world", result.response
          end

          test "handle_stdout parses step_start events and extracts session ID" do
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_abc","part":{}}')

            result = @invocation.instance_variable_get(:@result)
            assert_equal "ses_abc", result.session
          end

          test "handle_stdout increments turn count on step_start events" do
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_1","part":{}}')
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_1","part":{}}')

            assert_equal 2, @invocation.instance_variable_get(:@num_turns)
          end

          test "handle_stdout parses step_finish events and accumulates stats" do
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_1","part":{}}')
            @invocation.send(
              :handle_stdout,
              '{"type":"step_finish","sessionID":"ses_1","part":{"cost":0.015,"tokens":{"input":100,"output":50}}}',
            )

            result = @invocation.instance_variable_get(:@result)
            stats = result.stats
            assert_not_nil stats
            assert_in_delta 0.015, stats.usage.cost_usd
            assert_equal 100, stats.usage.input_tokens
            assert_equal 50, stats.usage.output_tokens
            assert_equal 1, stats.num_turns
          end

          test "handle_stdout accumulates stats across multiple step_finish events" do
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_1","part":{}}')
            @invocation.send(
              :handle_stdout,
              '{"type":"step_finish","sessionID":"ses_1","part":{"cost":0.01,"tokens":{"input":100,"output":50}}}',
            )
            @invocation.send(:handle_stdout, '{"type":"step_start","sessionID":"ses_1","part":{}}')
            @invocation.send(
              :handle_stdout,
              '{"type":"step_finish","sessionID":"ses_1","part":{"cost":0.02,"tokens":{"input":200,"output":100}}}',
            )

            result = @invocation.instance_variable_get(:@result)
            stats = result.stats
            assert_in_delta 0.03, stats.usage.cost_usd
            assert_equal 300, stats.usage.input_tokens
            assert_equal 150, stats.usage.output_tokens
            assert_equal 2, stats.num_turns
          end

          test "handle_stdout ignores empty lines" do
            @invocation.send(:handle_stdout, "")
            @invocation.send(:handle_stdout, "   ")

            result = @invocation.instance_variable_get(:@result)
            assert_equal "", result.response
          end

          test "handle_stdout ignores unparseable JSON" do
            @invocation.send(:handle_stdout, "not json at all")

            result = @invocation.instance_variable_get(:@result)
            assert_equal "", result.response
          end

          test "handle_stdout ignores unknown event types" do
            @invocation.send(:handle_stdout, '{"type":"unknown_event","data":"something"}')

            result = @invocation.instance_variable_get(:@result)
            assert_equal "", result.response
          end
        end

        class OpencodeInvocationRunTest < ActiveSupport::TestCase
          def setup
            @config = Agent::Config.new
            @config.no_show_progress!
            @input = Agent::Input.new
            @input.prompt = "test"
          end

          test "successful run completes with parsed output" do
            json_lines = [
              '{"type":"step_start","sessionID":"ses_1","part":{}}',
              '{"type":"text","sessionID":"ses_1","part":{"text":"Hello from opencode"}}',
              '{"type":"step_finish","sessionID":"ses_1","part":{"cost":0.01,"tokens":{"input":50,"output":25}}}',
            ]

            status = stub(success?: true)
            CommandRunner.expects(:execute).with(
              anything,
              working_directory: nil,
              stdout_handler: anything,
            ).returns(["", "", status]).tap do |expectation|
              expectation.with do |_cmd, **opts|
                json_lines.each { |line| opts[:stdout_handler].call(line) }
                true
              end
            end

            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            invocation.run!

            result = invocation.result
            assert_equal "Hello from opencode", result.response
            assert result.success
            assert_equal "ses_1", result.session
            assert_in_delta 0.01, result.stats.usage.cost_usd
          end

          test "failed run captures stderr in response" do
            status = stub(success?: false)
            CommandRunner.expects(:execute).returns(["", "command not found: opencode", status])

            invocation = Opencode::OpencodeInvocation.new(@config, @input)
            invocation.run!

            assert_raises(Opencode::OpencodeInvocation::OpencodeFailedError) do
              invocation.result
            end
          end
        end
      end
    end
  end
end
