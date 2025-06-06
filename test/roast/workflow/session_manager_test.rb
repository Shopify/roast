# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class SessionManagerTest < ActiveSupport::TestCase
      def setup
        @temp_dir = Dir.mktmpdir
        @file = File.join(@temp_dir, "test.rb")
        @workflow_id = 12345
        @session_name = "test_workflow"
        FileUtils.touch(@file)
        # Stub Dir.pwd to isolate the working directory
        Dir.stubs(:pwd).returns(@temp_dir)
        @manager = SessionManager.new
      end

      def teardown
        FileUtils.remove_entry(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
      end

      test "ensure_session_directory creates the directory structure" do
        session_dir = @manager.ensure_session_directory(@workflow_id, @session_name, @file)
        assert session_dir
        assert File.directory?(session_dir)
        assert File.exist?(File.join(File.dirname(session_dir), ".gitignore")), ".gitignore should exist"
      end

      test "ensure_session_directory reuses existing session" do
        first_session_dir = @manager.ensure_session_directory(@workflow_id, @session_name, @file)
        session_timestamp = @manager.session_timestamp(@workflow_id)
        assert session_timestamp
        second_session_dir = @manager.ensure_session_directory(@workflow_id, @session_name, @file)
        assert_equal first_session_dir, second_session_dir
      end

      test "find_session_directory returns nil when no directory exists" do
        result = @manager.find_session_directory(@session_name, @file)
        assert_nil result
      end

      test "find_session_directory finds the latest session" do
        workflow_dir = expected_workflow_dir
        FileUtils.mkdir_p(workflow_dir)
        old_session = "20240101_010101_001"
        new_session = "20240101_010101_002"
        FileUtils.mkdir_p(File.join(workflow_dir, old_session))
        FileUtils.mkdir_p(File.join(workflow_dir, new_session))
        result = @manager.find_session_directory(@session_name, @file)
        assert_equal File.join(workflow_dir, new_session), result
      end

      test "find_session_directory finds a specific timestamp when provided" do
        workflow_dir = expected_workflow_dir
        FileUtils.mkdir_p(workflow_dir)
        timestamp = "20240101_010101_001"
        session_dir = File.join(workflow_dir, timestamp)
        FileUtils.mkdir_p(session_dir)
        result = @manager.find_session_directory(@session_name, @file, timestamp)
        assert_equal session_dir, result
      end

      test "find_session_directory returns nil for nonexistent timestamp" do
        workflow_dir = expected_workflow_dir
        FileUtils.mkdir_p(workflow_dir)
        result = @manager.find_session_directory(@session_name, @file, "nonexistent")
        assert_nil result
      end

      test "session_timestamp returns the timestamp" do
        @manager.set_session_timestamp(@workflow_id, "20240101_010101_001")
        result = @manager.session_timestamp(@workflow_id)
        assert_equal "20240101_010101_001", result
      end

      test "create_new_session sets a timestamp" do
        result = @manager.create_new_session(@workflow_id)
        assert_match(/^\d{8}_\d{6}_\d{3}$/, result)
        assert_equal result, @manager.session_timestamp(@workflow_id)
      end

      private

      def expected_workflow_dir
        workflow_dir_name = @session_name.parameterize.underscore
        file_id = Digest::MD5.hexdigest(@file)
        file_basename = File.basename(@file).parameterize.underscore
        human_readable_id = "#{file_basename}_#{file_id[0..7]}"
        File.join(@temp_dir, ".roast", "sessions", workflow_dir_name, human_readable_id)
      end
    end
  end
end
