# frozen_string_literal: true

module FixtureHelpers
  def fixtures_dir
    File.expand_path("../fixtures", __dir__)
  end

  def fixture_files_dir
    File.join(fixtures_dir, "files")
  end

  def fixture_steps_dir
    File.join(fixtures_dir, "steps")
  end

  def fixture_file(filename)
    File.join(fixture_files_dir, filename)
  end

  def fixture_step(path)
    File.join(fixture_steps_dir, path)
  end
end

Minitest::Test.include(FixtureHelpers)
