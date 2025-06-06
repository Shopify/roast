# frozen_string_literal: true

require "test_helper"

class RoastTest < ActiveSupport::TestCase
  def test_config_file_returns_correct_path
    # Use a fixed path to make the test deterministic
    mock_home = "/mock/home"

    # Need to stub the actual HOME environment variable
    original_home = ENV["HOME"]
    begin
      ENV["HOME"] = mock_home
      expected_path = "#{mock_home}/.config/roast/token"

      # Reset cached value to pick up the new HOME
      Roast.instance_variable_set(:@config_file, nil)
      assert_equal(expected_path, Roast.config_file)
    ensure
      ENV["HOME"] = original_home
      Roast.instance_variable_set(:@config_file, nil)
    end
  end

  def test_store_token_creates_directory_and_writes_token
    mock_token = "new_mock_token"
    mock_config_dir = File.join(Dir.tmpdir, "roast_test_#{SecureRandom.hex(4)}")
    mock_config_file = "#{mock_config_dir}/token"

    begin
      Roast.stub(:config_file, mock_config_file) do
        assert_equal(mock_token, Roast.store_token(mock_token))
        assert(Dir.exist?(mock_config_dir), "Directory should have been created")
        assert(File.exist?(mock_config_file), "Token file should exist")
        assert_equal(mock_token, File.read(mock_config_file))
      end
    ensure
      FileUtils.rm_rf(mock_config_dir) if Dir.exist?(mock_config_dir)
    end
  end
end
