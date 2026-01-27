# frozen_string_literal: true

require "test_helper"

module Roast
  class Cog
    class ConfigTest < ActiveSupport::TestCase
      def setup
        @config = Config.new
      end

      test "initialize accepts initial hash" do
        config = Config.new({ key: "value", another: 42 })

        assert_equal "value", config.values[:key]
        assert_equal 42, config.values[:another]
      end

      test "validate! does nothing by default" do
        assert_nothing_raised do
          @config.validate!
        end
      end

      test "[]= sets a value" do
        @config[:key] = "value"

        assert_equal "value", @config.values[:key]
      end

      test "[] gets a value" do
        @config[:key] = "value"

        assert_equal "value", @config[:key]
      end

      test "[] returns nil for non-existent key" do
        assert_nil @config[:non_existent]
      end

      test "merge creates new config with combined values" do
        @config[:key1] = "value1"
        @config[:key2] = "value2"

        other = Config.new({ key2: "overridden", key3: "value3" })
        merged = @config.merge(other)

        assert_equal "value1", merged[:key1]
        assert_equal "overridden", merged[:key2]
        assert_equal "value3", merged[:key3]
      end

      test "merge does not modify original config" do
        @config[:key] = "original"
        other = Config.new({ key: "new" })

        @config.merge(other)

        assert_equal "original", @config[:key]
      end

      test "async! sets async to true" do
        @config.async!

        assert @config.async?
      end

      test "no_async! sets async to false" do
        @config.async!
        @config.no_async!

        refute @config.async?
      end

      test "sync! is alias for no_async!" do
        @config.async!
        @config.sync!

        refute @config.async?
      end

      test "async? returns false by default" do
        refute @config.async?
      end

      test "abort_on_failure! sets abort_on_failure to true" do
        @config.abort_on_failure!

        assert @config.abort_on_failure?
      end

      test "no_abort_on_failure! sets abort_on_failure to false" do
        @config.abort_on_failure!
        @config.no_abort_on_failure!

        refute @config.abort_on_failure?
      end

      test "continue_on_failure! is alias for no_abort_on_failure!" do
        @config.abort_on_failure!
        @config.continue_on_failure!

        refute @config.abort_on_failure?
      end

      test "abort_on_failure? returns false by default" do
        refute @config.abort_on_failure?
      end

      test "working_directory sets working directory" do
        @config.working_directory("/tmp")

        assert_equal "/tmp", @config.values[:working_directory]
      end

      test "use_current_working_directory! sets working directory to nil" do
        @config.working_directory("/tmp")
        @config.use_current_working_directory!

        assert_nil @config.values[:working_directory]
      end

      test "valid_working_directory returns nil when not set" do
        assert_nil @config.valid_working_directory
      end

      test "valid_working_directory returns expanded pathname for valid directory" do
        Dir.mktmpdir do |dir|
          @config.working_directory(dir)
          result = @config.valid_working_directory

          assert_equal Pathname.new(dir).expand_path, result
        end
      end

      test "valid_working_directory raises InvalidConfigError for non-existent directory" do
        @config.working_directory("/non/existent/path")

        error = assert_raises(Config::InvalidConfigError) do
          @config.valid_working_directory
        end

        assert_match(/does not exist/, error.message)
      end

      test "valid_working_directory raises InvalidConfigError for file instead of directory" do
        Tempfile.create("test_file") do |file|
          @config.working_directory(file.path)

          error = assert_raises(Config::InvalidConfigError) do
            @config.valid_working_directory
          end

          assert_match(/is not a directory/, error.message)
        end
      end

      test "field defines getter method" do
        test_class = Class.new(Config) do
          field :test_field, "default_value"
        end

        config = test_class.new

        assert_equal "default_value", config.test_field
      end

      test "field defines setter method" do
        test_class = Class.new(Config) do
          field :test_field, "default_value"
        end

        config = test_class.new
        config.test_field("new_value")

        assert_equal "new_value", config.test_field
      end

      test "field returns default when value not set" do
        test_class = Class.new(Config) do
          field :test_field, { key: "value" }
        end

        config = test_class.new

        assert_equal({ key: "value" }, config.test_field)
      end

      test "field deep dups default value" do
        test_class = Class.new(Config) do
          field :test_field, { key: "value" }
        end

        config = test_class.new
        result1 = config.test_field
        result2 = config.test_field

        refute_same result1, result2
      end

      test "field validator is called when setting value" do
        validator_called = false
        test_class = Class.new(Config) do
          field :test_field, "default" do |value|
            validator_called = true
            value.upcase
          end
        end

        config = test_class.new
        config.test_field("lowercase")

        assert validator_called
        assert_equal "LOWERCASE", config.test_field
      end

      test "field defines use_default method" do
        test_class = Class.new(Config) do
          field :test_field, "default_value"
        end

        config = test_class.new
        config.test_field("custom_value")
        config.use_default_test_field!

        assert_equal "default_value", config.test_field
      end

      test "field use_default method deep dups default" do
        test_class = Class.new(Config) do
          field :test_field, { key: "value" }
        end

        config = test_class.new
        config.use_default_test_field!
        result1 = config.test_field
        config.use_default_test_field!
        result2 = config.test_field

        refute_same result1, result2
      end
    end
  end
end
