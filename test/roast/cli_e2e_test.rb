# frozen_string_literal: true

require "test_helper"

module Roast
  class CLIE2ETest < ActiveSupport::TestCase
    ROAST_EXE = File.expand_path("../../exe/roast", __dir__)

    private def run_roast(*args, env: {})
      full_env = { "BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__) }.merge(env)
      stdout, stderr, status = Open3.capture3(full_env, "bundle", "exec", ROAST_EXE, *args)
      [stdout, stderr, status]
    end

    # ── version ──

    test "roast version prints the version string" do
      stdout, _stderr, status = run_roast("version")
      assert status.success?
      assert_match(/Roast version #{Regexp.escape(Roast::VERSION)}/, stdout)
    end

    # ── help ──

    test "roast help prints usage to stderr" do
      _stdout, stderr, status = run_roast("help")
      assert status.success?
      assert_match(/Usage: roast/, stderr)
      assert_match(/Commands:/, stderr)
    end

    test "roast --help prints usage to stderr" do
      _stdout, stderr, status = run_roast("--help")
      assert status.success?
      assert_match(/Usage: roast/, stderr)
    end

    test "roast -h prints usage to stderr" do
      _stdout, stderr, status = run_roast("-h")
      assert status.success?
      assert_match(/Usage: roast/, stderr)
    end

    # ── no args ──

    test "roast with no arguments prints help" do
      _stdout, stderr, status = run_roast
      assert status.success?
      assert_match(/Usage: roast/, stderr)
    end

    # ── unknown command ──

    test "roast with unknown command exits with status 1" do
      _stdout, stderr, status = run_roast("not_a_real_command")
      refute status.success?
      assert_equal 1, status.exitstatus
      assert_match(/Could not find command or workflow file/, stderr)
    end

    # ── execute without workflow ──

    test "roast execute without workflow file exits with status 1" do
      _stdout, stderr, status = run_roast("execute")
      refute status.success?
      assert_equal 1, status.exitstatus
      assert_match(/Workflow file is required/, stderr)
    end

    test "roast execute with nonexistent workflow exits with status 1" do
      _stdout, stderr, status = run_roast("execute", "nonexistent_workflow.rb")
      refute status.success?
      assert_equal 1, status.exitstatus
      assert_match(/Workflow file not found/, stderr)
    end

    # ── execute with a real workflow ──

    test "roast execute runs a workflow file" do
      stdout, stderr, status = run_roast("execute", "examples/outputs.rb")
      assert status.success?, "Expected success but got exit #{status.exitstatus}.\nstderr: #{stderr}"
      assert_match(/Upper:.*HELLO.*Original:.*Hello/, stdout)
    end

    test "roast runs a workflow file without the execute keyword" do
      stdout, stderr, status = run_roast("examples/outputs.rb")
      assert status.success?, "Expected success but got exit #{status.exitstatus}.\nstderr: #{stderr}"
      assert_match(/Upper:.*HELLO.*Original:.*Hello/, stdout)
    end

    # ── separator and custom args ──

    test "roast passes custom args after -- to the workflow" do
      stdout, stderr, status = run_roast(
        "examples/targets_and_params.rb",
        "--",
        "verbose",
        "name=test",
      )
      assert status.success?, "Expected success but got exit #{status.exitstatus}.\nstderr: #{stderr}"
      assert_match(/workflow args: \[:verbose\]/, stdout)
      assert_match(/workflow kwargs: \{name: "test"\}/, stdout)
    end

    test "roast passes targets to the workflow" do
      stdout, stderr, status = run_roast(
        "examples/targets_and_params.rb",
        "Gemfile",
      )
      assert status.success?, "Expected success but got exit #{status.exitstatus}.\nstderr: #{stderr}"
      assert_match(/workflow targets: \["Gemfile"\]/, stdout)
    end

    test "roast passes targets and custom args together" do
      stdout, stderr, status = run_roast(
        "examples/targets_and_params.rb",
        "Gemfile",
        "Rakefile",
        "--",
        "foo=bar",
        "debug",
      )
      assert status.success?, "Expected success but got exit #{status.exitstatus}.\nstderr: #{stderr}"
      assert_match(/workflow targets: \["Gemfile", "Rakefile"\]/, stdout)
      assert_match(/workflow args: \[:debug\]/, stdout)
      assert_match(/workflow kwargs: \{foo: "bar"\}/, stdout)
    end
  end
end
