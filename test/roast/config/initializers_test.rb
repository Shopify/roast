# frozen_string_literal: true

require "test_helper"

module Roast
  class InitializersTest < ActiveSupport::TestCase
    def path_for_initializers(name)
      File.join(Dir.pwd, "test", "fixtures", "initializers", name)
    end

    def test_with_invalid_initializers_folder
      initializer_path = path_for_initializers("invalid")

      Roast::Config::Initializers.stub(:path, initializer_path) do
        out, err = capture_io do
          Roast::Config::Initializers.load_all
        end

        assert_equal("", out)
        assert_equal("", err)
      end
    end

    def test_with_no_initializer_files
      initializer_path = path_for_initializers("empty")

      Roast::Config::Initializers.stub(:path, initializer_path) do
        out, err = capture_io do
          Roast::Config::Initializers.load_all
        end

        assert_equal("", out)
        expected_output = <<~OUTPUT
          Loading project initializers from #{initializer_path}
        OUTPUT
        assert_equal(expected_output, err)
      end
    end

    def test_with_initializer_file_that_raises
      initializer_path = path_for_initializers("raises")

      Roast::Config::Initializers.stub(:path, initializer_path) do
        out, err = capture_io do
          Roast::Config::Initializers.load_all
        end

        expected_output = <<~OUTPUT
          ERROR: Error loading initializers: exception class/object expected
        OUTPUT
        assert_includes(out, expected_output)
        expected_stderr = <<~OUTPUT
          Loading project initializers from #{initializer_path}
          Loading initializer: #{File.join(initializer_path, "hell.rb")}
        OUTPUT
        assert_equal(expected_stderr, err)
      end
    end

    def test_with_an_initializer_file
      initializer_path = path_for_initializers("single")

      Roast::Config::Initializers.stub(:path, initializer_path) do
        out, err = capture_io do
          Roast::Config::Initializers.load_all
        end

        assert_equal("", out)
        expected_output = <<~OUTPUT
          Loading project initializers from #{initializer_path}
          Loading initializer: #{File.join(initializer_path, "noop.rb")}
        OUTPUT
        assert_equal(expected_output, err)
      end
    end

    def test_with_multiple_initializer_files
      initializer_path = path_for_initializers("multiple")

      Roast::Config::Initializers.stub(:path, initializer_path) do
        out, err = capture_io do
          Roast::Config::Initializers.load_all
        end

        assert_equal("", out)
        expected_output = <<~OUTPUT
          Loading project initializers from #{initializer_path}
          Loading initializer: #{File.join(initializer_path, "first.rb")}
          Loading initializer: #{File.join(initializer_path, "second.rb")}
          Loading initializer: #{File.join(initializer_path, "third.rb")}
        OUTPUT
        assert_equal(expected_output, err)
      end
    end
  end
end
