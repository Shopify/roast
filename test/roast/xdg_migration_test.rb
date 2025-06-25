# frozen_string_literal: true

require "test_helper"

module Roast
  class XDGMigrationTest < ActiveSupport::TestCase
    include XDGHelper

    test "migrate_if_needed does nothing when no legacy directory exists" do
      with_fake_xdg_env do |temp_dir|
        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        XDGMigration.expects(:migrate_cache).never
        XDGMigration.expects(:migrate_sessions).never
        XDGMigration.expects(:migrate_initializers).never
        XDGMigration.expects(:migrate_sessions_db).never
        assert_empty output[0] # stdout should be empty
        refute_directory_exists(Roast::CONFIG_DIR)
        refute_directory_exists(Roast::CACHE_DIR)
      end
    end

    test "migrate_if_needed migrates cache files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy cache structure
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "function1.cache", "cached function 1")
        create_test_file(legacy_cache_dir, "subdir/function2.cache", "cached function 2")

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        assert_migration_output(output[0], "function cache")
        assert_migrated_files(
          Roast::FUNCTION_CACHE_DIR,
          "function1.cache" => "cached function 1",
          "subdir/function2.cache" => "cached function 2",
        )
      end
    end

    test "migrate_if_needed migrates session files" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy sessions structure
        legacy_sessions_dir = create_legacy_directory(temp_dir, "sessions")
        create_test_file(legacy_sessions_dir, "workflow1/session1/step_1.json", '{"step": "data"}')
        create_test_file(legacy_sessions_dir, "workflow2/session2/final_output.txt", "final output")

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        assert_migration_output(output[0], "session state")
        assert_migrated_files(
          Roast::SESSION_DATA_DIR,
          "workflow1/session1/step_1.json" => '{"step": "data"}',
          "workflow2/session2/final_output.txt" => "final output",
        )
      end
    end

    test "migrate_if_needed migrates sessions database" do
      with_fake_xdg_env do |temp_dir|
        refute(File.exist?(Roast::SESSION_DB_PATH))

        # Create legacy sessions database
        legacy_sessions_db_path = File.join(temp_dir, ".roast", "sessions.db")
        FileUtils.mkdir_p(File.dirname(legacy_sessions_db_path))
        FileUtils.touch(legacy_sessions_db_path)

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        assert_migration_output(output[0], "session database")
        assert(File.exist?(Roast::SESSION_DB_PATH))
      end
    end

    test "migrate_if_needed migrates all types together" do
      Roast::XDGMigration.unstub(:migrate_if_needed)
      with_fake_xdg_env do |temp_dir|
        # Create all legacy directory types
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        legacy_sessions_dir = create_legacy_directory(temp_dir, "sessions")
        legacy_initializers_dir = create_legacy_directory(temp_dir, "initializers")

        create_test_file(legacy_cache_dir, "cache_file.dat", "cache data")
        create_test_file(legacy_sessions_dir, "session_file.json", "session data")
        create_test_file(legacy_initializers_dir, "init_file.rb", "init data")

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        output_text = output[0]
        assert_includes output_text, "Found legacy .roast directory"
        assert_includes output_text, "function cache"
        assert_includes output_text, "session state"
        assert_includes output_text, "initializers"
        assert_includes output_text, "Migration complete!"

        # Verify all files migrated
        assert_migrated_files(
          Roast::FUNCTION_CACHE_DIR,
          "cache_file.dat" => "cache data",
        )
        assert_migrated_files(
          Roast::SESSION_DATA_DIR,
          "session_file.json" => "session data",
        )
        assert_migrated_files(
          File.join(temp_dir, "initializers"),
          "init_file.rb" => "init data",
        )
      end
    end

    test "migrate_if_needed skips empty legacy directories" do
      with_fake_xdg_env do |temp_dir|
        # Create empty legacy directories
        create_legacy_directory(temp_dir, "cache")
        create_legacy_directory(temp_dir, "sessions")
        # Don't create initializers to test partial migration

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
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
        xdg_cache_dir = Roast::FUNCTION_CACHE_DIR
        create_test_file(xdg_cache_dir, "existing.cache", "xdg content")

        capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
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
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(nested_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        assert_includes output[0], "Found legacy .roast directory"
        assert_migrated_files(
          Roast::FUNCTION_CACHE_DIR,
          "test.cache" => "test data",
        )
      end
    end

    test "legacy_dot_roast_dir finds .roast directory in current directory" do
      with_fake_xdg_env do |temp_dir|
        # Create .roast directory in temp_dir
        roast_dir = File.join(temp_dir, ".roast")
        FileUtils.mkdir_p(roast_dir)

        Dir.chdir(temp_dir) do
          found_dir = Roast::XDGMigration.legacy_dot_roast_dir
          assert_equal(File.realpath(roast_dir), File.realpath(found_dir))
        end
      end
    end

    test "legacy_dot_roast_dir finds .roast directory in parent directories" do
      with_fake_xdg_env do |temp_dir|
        # Create nested directory structure
        nested_dir = File.join(temp_dir, "project", "subdir", "deeper")
        FileUtils.mkdir_p(nested_dir)

        # Create .roast in parent
        roast_dir = File.join(temp_dir, ".roast")
        FileUtils.mkdir_p(roast_dir)

        Dir.chdir(nested_dir) do
          found_dir = Roast::XDGMigration.legacy_dot_roast_dir
          assert_equal(File.realpath(roast_dir), File.realpath(found_dir))
        end
      end
    end

    test "legacy_dot_roast_dir returns nil when no .roast directory exists" do
      with_fake_xdg_env do |temp_dir|
        assert_nil(Roast::XDGMigration.legacy_dot_roast_dir(temp_dir))
      end
    end

    test "legacy_dot_roast_dir respects ending_path boundary" do
      with_fake_xdg_env do |temp_dir|
        # Create nested structure
        ending_path = File.join(temp_dir, "boundary")
        search_dir = File.join(ending_path, "project", "deep")
        FileUtils.mkdir_p(search_dir)

        # Create .roast beyond the boundary
        roast_beyond = File.join(temp_dir, ".roast")
        FileUtils.mkdir_p(roast_beyond)

        Dir.chdir(search_dir) do
          found_dir = Roast::XDGMigration.legacy_dot_roast_dir(search_dir, ending_path)
          refute_equal(roast_beyond, found_dir)
        end
      end
    end

    test "migrate_if_needed handles roast directory with random content" do
      with_fake_xdg_env do |temp_dir|
        # Create .roast directory with known and unknown content
        roast_dir = File.join(temp_dir, ".roast")
        FileUtils.mkdir_p(roast_dir)

        # Add known subdirectories
        legacy_cache_dir = create_legacy_directory(temp_dir, "cache")
        create_test_file(legacy_cache_dir, "valid.cache", "cache data")

        # Add random/unexpected content
        create_test_file(roast_dir, "random_file.txt", "random content")
        create_test_file(roast_dir, "config.yml", "some: config")
        random_subdir = File.join(roast_dir, "unknown_subdir")
        FileUtils.mkdir_p(random_subdir)
        create_test_file(random_subdir, "stuff.rb", "puts 'hello'")

        # Add empty directory
        FileUtils.mkdir_p(File.join(roast_dir, "empty_dir"))

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        # Should migrate known content
        assert_includes output[0], "Found legacy .roast directory"
        assert_includes output[0], "function cache"
        assert_migrated_files(
          Roast::FUNCTION_CACHE_DIR,
          "valid.cache" => "cache data",
        )

        # Random files should remain in .roast directory (not migrated)
        assert_file_exists(File.join(roast_dir, "random_file.txt"))
        assert_file_exists(File.join(roast_dir, "config.yml"))
        assert_file_exists(File.join(random_subdir, "stuff.rb"))
        assert_directory_exists(File.join(roast_dir, "empty_dir"))
      end
    end

    test "migrate_initializers doesn't overwrite existing files in target directory" do
      with_fake_xdg_env do |temp_dir|
        # Create legacy initializers directory
        legacy_initializers_dir = create_legacy_directory(temp_dir, "initializers")
        create_test_file(legacy_initializers_dir, "config.rb", "# legacy config")
        create_test_file(legacy_initializers_dir, "setup.rb", "# legacy setup")
        create_test_file(legacy_initializers_dir, "subdir/nested.rb", "# legacy nested")

        # Create existing initializers directory with some files
        existing_initializers_dir = File.join(temp_dir, "initializers")
        create_test_file(existing_initializers_dir, "config.rb", "# existing config")
        create_test_file(existing_initializers_dir, "other.rb", "# existing other")

        output = capture_io do
          # Ensure logger uses captured stdout
          Roast::Helpers::Logger.reset
          Dir.chdir(temp_dir) do
            Roast::XDGMigration.migrate_if_needed
          end
        end

        assert_includes output[0], "Found legacy .roast directory"
        assert_includes output[0], "initializers"

        # Existing files should not be overwritten
        assert_file_content(File.join(existing_initializers_dir, "config.rb"), "# existing config")
        assert_file_content(File.join(existing_initializers_dir, "other.rb"), "# existing other")

        # New files should be migrated
        assert_file_content(File.join(existing_initializers_dir, "setup.rb"), "# legacy setup")
        assert_file_content(File.join(existing_initializers_dir, "subdir/nested.rb"), "# legacy nested")
      end
    end

    private

    def create_legacy_directory(temp_dir, subdir_name)
      legacy_roast_dir = File.join(temp_dir, ".roast")
      dir_path = File.join(legacy_roast_dir, subdir_name)
      FileUtils.mkdir_p(dir_path)
      dir_path
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

    def create_test_file(base_dir, relative_path, content)
      file_path = File.join(base_dir, relative_path)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, content)
      file_path
    end
  end
end
