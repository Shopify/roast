# frozen_string_literal: true

require "test_helper"

module Roast
  class InitializersTest < ActiveSupport::TestCase
    include XDGHelper

    test "load_all with no initializer files" do
      with_fake_xdg_env do |temp_dir|
        Dir.chdir(temp_dir) do
          refute(Dir.exist?(Roast::GLOBAL_INITIALIZERS_DIR))
          refute(Dir.exist?(File.join(temp_dir, "initializers")))
          refute(Dir.exist?(File.join(temp_dir, ".roast", "initializers")))

          Roast::Initializers.expects(:load_initializer).never
          Roast::Initializers.load_all
        end
      end
    end

    test "load_all with initializer file that raises" do
      initializer_path = initializers_fixture_path("raises")
      expected_file = File.join(initializer_path, "hell.rb")

      Roast::Initializers.stub(:initializer_files, [expected_file]) do
        Roast::Initializers.expects(:load_initializer).with(expected_file).raises(StandardError, "exception class/object expected")

        out, _err = capture_io do
          Roast::Initializers.load_all
        end

        expected_output = <<~OUTPUT
          ERROR: Error loading initializers: exception class/object expected
        OUTPUT
        assert_includes(out, expected_output)
      end
    end

    test "load_all with an initializer file" do
      initializer_path = initializers_fixture_path("single")
      expected_file = File.join(initializer_path, "noop.rb")

      Roast::Initializers.stub(:initializer_files, [expected_file]) do
        Roast::Initializers.expects(:load_initializer).with(expected_file).once
        Roast::Initializers.load_all
      end
    end

    test "load_all with multiple initializer files" do
      initializer_path = initializers_fixture_path("multiple")
      expected_files = [
        File.join(initializer_path, "first.rb"),
        File.join(initializer_path, "second.rb"),
        File.join(initializer_path, "third.rb"),
      ]

      Roast::Initializers.stub(:initializer_files, expected_files) do
        expected_files.each do |file|
          Roast::Initializers.expects(:load_initializer).with(file).once
        end
        Roast::Initializers.load_all
      end
    end

    test "load_all prioritizes local over global" do
      with_fake_xdg_env do |temp_dir|
        temp_dir = File.realpath(temp_dir)

        global_init_file = File.join(Roast::GLOBAL_INITIALIZERS_DIR, "noop.rb")
        FileUtils.mkdir_p(File.dirname(global_init_file))
        File.write(global_init_file, "puts 'global initializer'")

        local_init_file = File.join(temp_dir, "initializers", "noop.rb")
        FileUtils.mkdir_p(File.dirname(local_init_file))
        File.write(local_init_file, "puts 'local initializer'")

        Dir.chdir(temp_dir) do
          out, _err = capture_io do
            Roast::Initializers.load_all
          end

          assert_includes(out, "local initializer")
          refute_includes(out, "global initializer")
        end
      end
    end

    test "load_all loads in priority order" do
      with_fake_xdg_env do |temp_dir|
        temp_dir = File.realpath(temp_dir)

        local_init_file = File.join(temp_dir, "initializers", "local.rb")
        FileUtils.mkdir_p(File.dirname(local_init_file))
        File.write(local_init_file, "puts 'local initializer'")

        global_init_file = File.join(Roast::GLOBAL_INITIALIZERS_DIR, "global.rb")
        FileUtils.mkdir_p(File.dirname(global_init_file))
        File.write(global_init_file, "puts 'global initializer'")

        legacy_init_file = File.join(temp_dir, ".roast", "initializers", "legacy.rb")
        FileUtils.mkdir_p(File.dirname(legacy_init_file))
        File.write(legacy_init_file, "puts 'legacy initializer'")

        Dir.chdir(temp_dir) do
          out, _err = capture_io do
            Roast::Initializers.load_all
          end

          # We should see legacy first, then global, then local
          assert_equal("legacy initializer\nglobal initializer\nlocal initializer\n", out)
        end
      end
    end

    test "initializer_files overrides global with local initializers" do
      with_fake_xdg_env do |temp_dir|
        temp_dir = File.realpath(temp_dir)

        global_init_file = File.join(Roast::GLOBAL_INITIALIZERS_DIR, "noop.rb")
        FileUtils.mkdir_p(File.dirname(global_init_file))
        File.write(global_init_file, "puts 'global initializer'")

        local_init_file = File.join(temp_dir, "initializers", "noop.rb")
        FileUtils.mkdir_p(File.dirname(local_init_file))
        File.write(local_init_file, "puts 'local initializer'")

        Dir.chdir(temp_dir) do
          files = Roast::Initializers.send(:initializer_files)
          assert_equal([local_init_file], files)
        end
      end
    end

    test "initializer_files returns files in priority order" do
      with_fake_xdg_env do |temp_dir|
        temp_dir = File.realpath(temp_dir)

        # Local > Global > Legacy

        FileUtils.mkdir_p(Roast::GLOBAL_INITIALIZERS_DIR)
        global_init_file = File.join(Roast::GLOBAL_INITIALIZERS_DIR, "global.rb")
        File.write(global_init_file, "puts 'global initializer'")

        local_init_file = File.join(temp_dir, "initializers", "local.rb")
        FileUtils.mkdir_p(File.dirname(local_init_file))
        File.write(local_init_file, "puts 'local initializer'")

        legacy_init_file = File.join(temp_dir, ".roast", "initializers", "legacy.rb")
        FileUtils.mkdir_p(File.dirname(legacy_init_file))
        File.write(legacy_init_file, "puts 'legacy initializer'")

        Dir.chdir(temp_dir) do
          files = Roast::Initializers.send(:initializer_files)
          assert_equal([local_init_file, global_init_file, legacy_init_file], files)
        end
      end
    end

    private

    def initializers_fixture_path(name)
      File.join(Dir.pwd, "test", "fixtures", "initializers", name)
    end
  end
end
