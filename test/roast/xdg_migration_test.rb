# frozen_string_literal: true

require "test_helper"

module Roast
  class XDGMigrationTest < ActiveSupport::TestCase
    test "migrate_if_needed does nothing when no legacy directory exists" do
      with_fake_xdg_env do |temp_dir|
        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        assert_empty output[0] # stdout should be empty
        refute_directory_exists(Roast::XDG::Config.root)
        refute_directory_exists(Roast::XDG::Cache.root)
        refute_directory_exists(Roast::XDG::State.root)
      end
    end

    test "migrate_if_needed migrates cache files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy cache structure
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "function1.cache", "cached function 1")
        create_test_file(legacy_cache_dir, "subdir/function2.cache", "cached function 2")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        assert_migration_output(output[0], "function cache")
        assert_migrated_files(
          Roast::XDG::Cache.subdir(:functions),
          "function1.cache" => "cached function 1",
          "subdir/function2.cache" => "cached function 2",
        )
        assert_gitignore_exists(Roast::XDG::Cache.subdir(:functions))
      end
    end

    test "migrate_if_needed migrates session files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy sessions structure
        legacy_sessions_dir = create_legacy_directory(temp_dir, "sessions")
        create_test_file(legacy_sessions_dir, "workflow1/session1/step_1.json", '{"step": "data"}')
        create_test_file(legacy_sessions_dir, "workflow2/session2/final_output.txt", "final output")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        assert_migration_output(output[0], "session state")
        assert_migrated_files(
          Roast::XDG::State.subdir(:sessions),
          "workflow1/session1/step_1.json" => '{"step": "data"}',
          "workflow2/session2/final_output.txt" => "final output",
        )
        assert_gitignore_exists(Roast::XDG::State.subdir(:sessions))
      end
    end

    test "migrate_if_needed migrates initializer files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy initializers structure
        legacy_initializers_dir = create_legacy_directory(temp_dir, "initializers")
        create_test_file(legacy_initializers_dir, "common.rb", "# Common initializer")
        create_test_file(legacy_initializers_dir, "project/specific.rb", "# Project specific")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        assert_migration_output(output[0], "initializers")
        assert_migrated_files(
          Roast::XDG::Config.subdir(:initializers),
          "common.rb" => "# Common initializer",
          "project/specific.rb" => "# Project specific",
        )
        refute_gitignore_exists(Roast::XDG::Config.subdir(:initializers))
      end
    end

    test "migrate_if_needed migrates all types together" do
      with_fake_xdg_env do |temp_dir|
        # Create all legacy directory types
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        legacy_sessions_dir = create_legacy_directory(temp_dir, "sessions")
        legacy_initializers_dir = create_legacy_directory(temp_dir, "initializers")

        create_test_file(legacy_cache_dir, "cache_file.dat", "cache data")
        create_test_file(legacy_sessions_dir, "session_file.json", "session data")
        create_test_file(legacy_initializers_dir, "init_file.rb", "init data")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        output_text = output[0]
        assert_includes output_text, "Found legacy .roast directory"
        assert_includes output_text, "function cache"
        assert_includes output_text, "session state"
        assert_includes output_text, "initializers"
        assert_includes output_text, "Migration complete!"

        # Verify all files migrated
        assert_migrated_files(
          Roast::XDG::Cache.subdir(:functions),
          "cache_file.dat" => "cache data",
        )
        assert_migrated_files(
          Roast::XDG::State.subdir(:sessions),
          "session_file.json" => "session data",
        )
        assert_migrated_files(
          Roast::XDG::Config.subdir(:initializers),
          "init_file.rb" => "init data",
        )
      end
    end

    test "migrate_if_needed handles errors gracefully" do
      with_fake_xdg_env do |temp_dir|
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "test.cache", "test data")

        # Stub FileUtils.cp to raise an error
        FileUtils.stubs(:cp).raises(StandardError, "Permission denied")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        assert_includes output[0], "Error migrating function cache"
        assert_includes output[0], "Permission denied"
      end
    end

    test "migrate_if_needed skips empty legacy directories" do
      with_fake_xdg_env do |temp_dir|
        # Create empty legacy directories
        create_legacy_directory(temp_dir, "cache")
        create_legacy_directory(temp_dir, "sessions")
        # Don't create initializers to test partial migration

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        output_text = output[0]
        assert_includes output_text, "Found legacy .roast directory"
        # Should only migrate cache and sessions, not initializers
        assert_includes output_text, "function cache"
        assert_includes output_text, "session state"
        refute_includes output_text, "initializers"
      end
    end

    test "migrate_if_needed doesn't overwrite existing files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy cache
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "existing.cache", "legacy content")

        # Create existing XDG file
        xdg_cache_dir = Roast::XDG::Cache.subdir(:functions)
        create_test_file(xdg_cache_dir, "existing.cache", "xdg content")

        capture_io do
          Roast::XDGMigration.migrate_if_needed(temp_dir)
        end

        # File should retain XDG content, not be overwritten
        assert_file_content(File.join(xdg_cache_dir, "existing.cache"), "xdg content")
      end
    end

    test "migrate_if_needed finds legacy directory in parent directories" do
      with_fake_xdg_env do |temp_dir|
        # Create nested directory structure
        nested_dir = File.join(temp_dir, "project", "subdir", "deeper")
        FileUtils.mkdir_p(nested_dir)

        # Create legacy .roast in parent
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "test.cache", "test data")

        output = capture_io do
          Roast::XDGMigration.migrate_if_needed(nested_dir)
        end

        assert_includes output[0], "Found legacy .roast directory"
        assert_migrated_files(
          Roast::XDG::Cache.subdir(:functions),
          "test.cache" => "test data",
        )
      end
    end

    private

    def with_fake_xdg_env
      temp_dir = Dir.mktmpdir("roast_xdg_migration_test")
      original_home = ENV["HOME"]
      original_xdg_config = ENV["XDG_CONFIG_HOME"]
      original_xdg_cache = ENV["XDG_CACHE_HOME"]
      original_xdg_state = ENV["XDG_STATE_HOME"]

      begin
        # Set up temporary XDG directories within our test temp dir
        ENV["HOME"] = temp_dir
        ENV["XDG_CONFIG_HOME"] = File.join(temp_dir, ".config")
        ENV["XDG_CACHE_HOME"] = File.join(temp_dir, ".cache")
        ENV["XDG_STATE_HOME"] = File.join(temp_dir, ".local", "state")

        yield temp_dir
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir && File.exist?(temp_dir)
        ENV["HOME"] = original_home
        ENV["XDG_CONFIG_HOME"] = original_xdg_config
        ENV["XDG_CACHE_HOME"] = original_xdg_cache
        ENV["XDG_STATE_HOME"] = original_xdg_state
      end
    end

    def create_legacy_directory(temp_dir, subdir_name)
      legacy_roast_dir = File.join(temp_dir, ".roast")
      dir_path = File.join(legacy_roast_dir, subdir_name)
      FileUtils.mkdir_p(dir_path)
      dir_path
    end

    def create_test_file(base_dir, relative_path, content)
      file_path = File.join(base_dir, relative_path)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, content)
      file_path
    end

    def assert_migration_output(output, description)
      assert_includes(output, "Found legacy .roast directory")
      assert_includes(output, "Migrating #{description}")
      assert_includes(output, "Migration complete!")
    end

    def assert_migrated_files(target_dir, file_expectations)
      file_expectations.each do |relative_path, expected_content|
        file_path = File.join(target_dir, relative_path)
        assert_file_exists(file_path)
        assert_file_content(file_path, expected_content)
      end
    end

    def assert_file_exists(file_path)
      assert(File.exist?(file_path), "Expected file to exist: #{file_path}")
    end

    def assert_file_content(file_path, expected_content)
      actual_content = File.read(file_path)
      assert_equal(
        expected_content,
        actual_content,
        "File content mismatch in #{file_path}",
      )
    end

    def assert_directory_exists(dir_path)
      assert(File.directory?(dir_path), "Expected directory to exist: #{dir_path}")
    end

    def refute_directory_exists(dir_path)
      refute(File.directory?(dir_path), "Expected directory to not exist: #{dir_path}")
    end

    def assert_gitignore_exists(dir_path)
      gitignore_path = File.join(dir_path, ".gitignore")
      assert_file_exists(gitignore_path)
      assert_file_content(gitignore_path, "*\n")
    end

    def refute_gitignore_exists(dir_path)
      gitignore_path = File.join(dir_path, ".gitignore")
      refute(File.exist?(gitignore_path), "Expected .gitignore to not exist: #{gitignore_path}")
    end
  end
end
