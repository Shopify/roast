# frozen_string_literal: true

require "test_helper"

module Roast
  module Cogs
    class Agent < Cog
      class ConfigTest < ActiveSupport::TestCase
        def setup
          @config = Config.new
          @default_provider = Provider.default_provider_name
        end

        test "provider sets provider value" do
          @config.provider(@default_provider)

          assert_equal @default_provider, @config.valid_provider!
        end

        test "use_default_provider! clears provider value" do
          @config.provider(:fake_provider)
          @config.use_default_provider!

          assert_equal @default_provider, @config.valid_provider!
        end

        test "valid_provider! returns default when not set" do
          assert_equal @default_provider, @config.valid_provider!
        end

        test "valid_provider! raises on invalid provider" do
          @config.provider(:invalid_provider)

          error = assert_raises(ArgumentError) do
            @config.valid_provider!
          end

          assert_match(/invalid_provider.*not a valid provider/, error.message)
        end

        # Command configuration tests
        test "command sets command value" do
          @config.command("test-command")

          assert_equal "test-command", @config.valid_command
        end

        test "command accepts array" do
          @config.command(["test-cmd", "arg1", "arg2"])

          assert_equal ["test-cmd", "arg1", "arg2"], @config.valid_command
        end

        test "use_default_command! clears command value" do
          @config.command("test-command")
          @config.use_default_command!

          assert_nil @config.valid_command
        end

        test "valid_command returns nil when not set" do
          assert_nil @config.valid_command
        end

        test "valid_command returns nil for empty string" do
          @config.command("")

          assert_nil @config.valid_command
        end

        # Model configuration tests
        test "model sets model value" do
          @config.model("test-model")

          assert_equal "test-model", @config.valid_model
        end

        test "use_default_model! clears model value" do
          @config.model("test-model")
          @config.use_default_model!

          assert_nil @config.valid_model
        end

        test "valid_model returns nil when not set" do
          assert_nil @config.valid_model
        end

        # System prompt configuration tests
        test "replace_system_prompt sets replacement prompt" do
          @config.replace_system_prompt("Custom prompt")

          assert_equal "Custom prompt", @config.valid_replace_system_prompt
        end

        test "no_replace_system_prompt! clears replacement prompt" do
          @config.replace_system_prompt("Custom")
          @config.no_replace_system_prompt!

          assert_nil @config.valid_replace_system_prompt
        end

        test "valid_replace_system_prompt returns nil when not set" do
          assert_nil @config.valid_replace_system_prompt
        end

        test "append_system_prompt sets appended prompt" do
          @config.append_system_prompt("Additional instructions")

          assert_equal "Additional instructions", @config.valid_append_system_prompt
        end

        test "no_append_system_prompt! clears appended prompt" do
          @config.append_system_prompt("Additional")
          @config.no_append_system_prompt!

          assert_nil @config.valid_append_system_prompt
        end

        test "valid_append_system_prompt returns nil when not set" do
          assert_nil @config.valid_append_system_prompt
        end

        # Permissions configuration tests
        test "apply_permissions! enables permissions" do
          # ensure that configured value is initially the opposite of what we want to test
          @config.no_apply_permissions!
          refute @config.apply_permissions?

          @config.apply_permissions!

          assert @config.apply_permissions?
        end

        test "no_apply_permissions! disables permissions" do
          # ensure that configured value is initially the opposite of what we want to test
          @config.apply_permissions!
          assert @config.apply_permissions?

          @config.no_apply_permissions!

          refute @config.apply_permissions?
        end

        test "apply_permissions? returns true by default" do
          assert @config.apply_permissions?
        end

        test "skip_permissions! is alias for no_apply_permissions!" do
          # ensure that configured value is initially the opposite of what we want to test
          @config.apply_permissions!
          assert @config.apply_permissions?

          @config.skip_permissions!

          refute @config.apply_permissions?
        end

        test "no_skip_permissions! is alias for apply_permissions!" do
          # ensure that configured value is initially the opposite of what we want to test
          @config.no_apply_permissions!
          refute @config.apply_permissions?

          @config.no_skip_permissions!

          assert @config.apply_permissions?
        end

        # Display configuration tests
        test "show_prompt! enables prompt display" do
          @config.show_prompt!

          assert @config.show_prompt?
        end

        test "no_show_prompt! disables prompt display" do
          @config.show_prompt!
          @config.no_show_prompt!

          refute @config.show_prompt?
        end

        test "show_prompt? returns false by default" do
          refute @config.show_prompt?
        end

        test "show_progress! enables progress display" do
          @config.show_progress!

          assert @config.show_progress?
        end

        test "no_show_progress! disables progress display" do
          @config.no_show_progress!

          refute @config.show_progress?
        end

        test "show_progress? returns true by default" do
          assert @config.show_progress?
        end

        test "show_response! enables response display" do
          @config.show_response!

          assert @config.show_response?
        end

        test "no_show_response! disables response display" do
          @config.no_show_response!

          refute @config.show_response?
        end

        test "show_response? returns true by default" do
          assert @config.show_response?
        end

        test "show_stats! enables stats display" do
          @config.show_stats!

          assert @config.show_stats?
        end

        test "no_show_stats! disables stats display" do
          @config.no_show_stats!

          refute @config.show_stats?
        end

        test "show_stats? returns true by default" do
          assert @config.show_stats?
        end

        test "display! enables all display options" do
          @config.no_display!
          @config.display!

          assert @config.show_prompt?
          assert @config.show_progress?
          assert @config.show_response?
          assert @config.show_stats?
        end

        test "no_display! disables all display options" do
          @config.display!
          @config.no_display!

          refute @config.show_prompt?
          refute @config.show_progress?
          refute @config.show_response?
          refute @config.show_stats?
        end

        test "quiet! is alias for no_display!" do
          @config.display!
          @config.quiet!

          refute @config.show_prompt?
          refute @config.show_progress?
          refute @config.show_response?
          refute @config.show_stats?
        end

        test "display? returns true when any display option is enabled" do
          @config.no_display!
          @config.show_prompt!

          assert @config.display?
        end

        test "display? returns false when all display options are disabled" do
          @config.no_display!

          refute @config.display?
        end

        # Debug configuration tests
        test "dump_raw_agent_messages_to sets dump path" do
          test_path = File.join(Dir.tmpdir, "messages.log")
          @config.dump_raw_agent_messages_to(test_path)

          assert_equal Pathname.new(test_path), @config.valid_dump_raw_agent_messages_to_path
        end

        test "valid_dump_raw_agent_messages_to_path returns nil when not set" do
          assert_nil @config.valid_dump_raw_agent_messages_to_path
        end
      end
    end
  end
end
