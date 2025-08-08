# frozen_string_literal: true

require "test_helper"

module Roast
  class ConfigRootTest < ActiveSupport::TestCase
    def ending_path
      File.join(Roast::ROOT, "test", "fixtures", "config_root")
    end

    def test_with_no_roast_folder
      starting_path = File.join(ending_path, "empty")
      path = Roast::Initializers.config_root(starting_path, ending_path)
      expected_path = File.join(starting_path, ".roast")
      assert_equal(expected_path, path)
    end

    def test_with_shallow_roast_folder
      starting_path = File.join(ending_path, "shallow")
      path = Roast::Initializers.config_root(starting_path, ending_path)
      expected_path = File.join(starting_path, ".roast")
      assert_equal(expected_path, path)
    end

    def test_with_nested_roast_folder
      starting_path = File.join(ending_path, "deeply", "nested", "start", "folder")
      path = Roast::Initializers.config_root(starting_path, ending_path)
      expected_path = File.join(ending_path, "deeply", ".roast")
      assert_equal(expected_path, path)
    end
  end

  class InitializersTest < ActiveSupport::TestCase
    def path_for_initializers(name)
      File.join(Dir.pwd, "test", "fixtures", "initializers", name)
    end

    def test_with_invalid_initializers_folder
      initializer_path = path_for_initializers("invalid")

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
        end

        assert_equal("", out)
        assert_equal("", err)
      end
    end

    def test_with_no_initializer_files
      initializer_path = path_for_initializers("empty")

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
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

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
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

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
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

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
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

    def test_with_numeric_prefixed_initializer_files
      initializer_path = path_for_initializers("numeric_order")

      Roast::Initializers.stub(:initializers_path, initializer_path) do
        out, err = capture_io do
          Roast::Initializers.load_all
        end

        # Verify files are loaded in numeric order (01, 02, 03, 10, 20)
        # not lexicographic order (01, 02, 03, 10, 20 vs 01, 02, 03, 10, 20)
        expected_stderr = <<~OUTPUT
          Loading project initializers from #{initializer_path}
          Loading initializer: #{File.join(initializer_path, "01_first.rb")}
          Loading initializer: #{File.join(initializer_path, "02_second.rb")}
          Loading initializer: #{File.join(initializer_path, "03_third.rb")}
          Loading initializer: #{File.join(initializer_path, "10_tenth.rb")}
          Loading initializer: #{File.join(initializer_path, "20_twentieth.rb")}
        OUTPUT
        assert_equal(expected_stderr, err)

        # Verify the execution order through stdout
        expected_stdout = <<~OUTPUT
          Loaded: 01_first
          Loaded: 02_second
          Loaded: 03_third
          Loaded: 10_tenth
          Loaded: 20_twentieth
        OUTPUT
        assert_equal(expected_stdout, out)
      end
    end
  end
end
