# frozen_string_literal: true

require "test_helper"

module Roast
  class Config
    class CacheTest < ActiveSupport::TestCase
      def setup
        @original_config_root = Roast::Config.method(:root)
        @test_cache_path = File.join(Dir.mktmpdir, ".roast", "cache")
      end

      def teardown
        FileUtils.rm_rf(File.dirname(@test_cache_path)) if File.exist?(File.dirname(@test_cache_path))
      end

      def test_path_returns_cache_directory_under_config_root
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          expected_path = @test_cache_path
          assert_equal(expected_path, Roast::Config::Cache.path)
        end
      end

      def test_ensure_exists_creates_cache_directory
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          refute(File.directory?(@test_cache_path))

          Roast::Config::Cache.ensure_exists

          assert(File.directory?(@test_cache_path))
        end
      end

      def test_ensure_exists_does_not_fail_if_directory_already_exists
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          FileUtils.mkdir_p(@test_cache_path)
          assert(File.directory?(@test_cache_path))

          assert_nothing_raised do
            Roast::Config::Cache.ensure_exists
          end

          assert(File.directory?(@test_cache_path))
        end
      end

      def test_gitignore_path_returns_correct_path
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          expected_path = File.join(@test_cache_path, ".gitignore")
          assert_equal(expected_path, Roast::Config::Cache.gitignore_path)
        end
      end

      def test_ensure_gitignore_exists_creates_gitignore_file
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          FileUtils.mkdir_p(@test_cache_path)
          gitignore_path = File.join(@test_cache_path, ".gitignore")
          refute(File.exist?(gitignore_path))

          Roast::Config::Cache.ensure_gitignore_exists

          assert(File.exist?(gitignore_path))
          assert_equal("*", File.read(gitignore_path))
        end
      end

      def test_ensure_gitignore_exists_does_not_overwrite_existing_file
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          FileUtils.mkdir_p(@test_cache_path)
          gitignore_path = File.join(@test_cache_path, ".gitignore")
          File.write(gitignore_path, "custom content")

          Roast::Config::Cache.ensure_gitignore_exists

          assert_equal("custom content", File.read(gitignore_path))
        end
      end

      def test_for_ensures_directory_and_gitignore_exist
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          refute(File.directory?(@test_cache_path))
          gitignore_path = File.join(@test_cache_path, ".gitignore")
          refute(File.exist?(gitignore_path))

          cache = Roast::Config::Cache.for

          assert(File.directory?(@test_cache_path))
          assert(File.exist?(gitignore_path))
          assert_equal("*", File.read(gitignore_path))
          assert_instance_of(ActiveSupport::Cache::FileStore, cache)
        end
      end

      def test_for_returns_file_store_cache_instance
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          cache = Roast::Config::Cache.for

          assert_instance_of(ActiveSupport::Cache::FileStore, cache)
        end
      end

      def test_for_sets_correct_cache_path
        Roast::Config.stub(:root, File.dirname(@test_cache_path)) do
          cache = Roast::Config::Cache.for

          # Access the cache_path through the FileStore's options
          assert_equal(@test_cache_path, cache.cache_path)
        end
      end
    end
  end
end
