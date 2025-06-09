# frozen_string_literal: true

require "test_helper"

module Roast
  class DotRoastDirTest < ActiveSupport::TestCase
    def ending_path
      File.join(Roast::ROOT, "test", "fixtures", "config_root")
    end

    def test_with_no_roast_folder
      starting_path = File.join(ending_path, "empty")
      path = Roast.dot_roast_dir(starting_path, ending_path)
      expected_path = File.join(starting_path, ".roast")
      assert_equal(expected_path, path)
    end

    def test_with_shallow_roast_folder
      starting_path = File.join(ending_path, "shallow")
      path = Roast.dot_roast_dir(starting_path, ending_path)
      expected_path = File.join(starting_path, ".roast")
      assert_equal(expected_path, path)
    end

    def test_with_nested_roast_folder
      starting_path = File.join(ending_path, "deeply", "nested", "start", "folder")
      path = Roast.dot_roast_dir(starting_path, ending_path)
      expected_path = File.join(ending_path, "deeply", ".roast")
      assert_equal(expected_path, path)
    end

    def test_starting_path_not_subdir_of_ending_path
      Dir.mktmpdir do |tmpdir|
        starting_path = tmpdir

        Roast::Helpers::Logger.expects(:warn).once

        path = Roast.dot_roast_dir(starting_path, ending_path)
        expected_path = File.join(starting_path, ".roast")
        assert_equal(expected_path, path)
      end
    end
  end
end
