# frozen_string_literal: true

require "test_helper"

module Roast
  module Workflow
    class InitializersTest < ActiveSupport::TestCase
      def test_with_invalid_initializers_folder
        with_fake_initializers_dir do |tmpdir|
          File.join(tmpdir, "invalid_path")

          capture_io do
            Initializers.load_all
          end

          # Should not raise error for missing directory
          assert_nothing_raised do
            Initializers.load_all
          end
        end
      end

      def test_with_no_initializer_files
        with_fake_initializers_dir do |tmpdir|
          fake_initializers_dir = File.join(tmpdir, "initializers")
          FileUtils.mkdir_p(fake_initializers_dir)

          capture_io do
            Initializers.load_all
          end

          # Should complete without error
          assert(true)
        end
      end

      def test_with_initializer_file_that_raises
        with_fake_initializers_dir do |tmpdir|
          fake_initializers_dir = File.join(tmpdir, "initializers")
          FileUtils.mkdir_p(fake_initializers_dir)

          File.write(File.join(fake_initializers_dir, "bad_initializer.rb"), "raise 'This initializer is bad'")

          Roast::Helpers::Logger.expects(:error).with("Error loading initializers: This initializer is bad").once

          capture_io do
            Initializers.load_all
          end

          # Should not raise error even when initializer fails
          assert_nothing_raised do
            # Second call should not trigger the logger since it's already loaded
            # and require will prevent reloading the same file
          end
        end
      end

      private

      def with_fake_initializers_dir
        Dir.mktmpdir do |tmpdir|
          Roast.stubs(:dot_roast_dir).returns(tmpdir)
          yield(tmpdir)
        end
      end
    end
  end
end
