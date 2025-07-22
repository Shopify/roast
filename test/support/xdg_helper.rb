# frozen_string_literal: true

module XDGHelper
  include RedefineConstants

  def with_fake_xdg_env
    Dir.mktmpdir do |temp_dir|
      stub_xdg_env(temp_dir)

      yield temp_dir
    ensure
      unstub_xdg_env
    end
  end

  def stub_xdg_env(temp_dir)
    redefine_constant(Roast, :XDG_CONFIG_HOME, File.join(temp_dir, ".config"))
    redefine_constant(Roast, :XDG_CACHE_HOME, File.join(temp_dir, ".cache"))

    redefine_constant(Roast, :CONFIG_DIR, File.join(Roast::XDG_CONFIG_HOME, "roast"))
    redefine_constant(Roast, :CACHE_DIR, File.join(Roast::XDG_CACHE_HOME, "roast"))

    redefine_constant(Roast, :GLOBAL_INITIALIZERS_DIR, File.join(Roast::CONFIG_DIR, "initializers"))
    redefine_constant(Roast, :FUNCTION_CACHE_DIR, File.join(Roast::CACHE_DIR, "function_calls"))
    redefine_constant(Roast, :SESSION_DATA_DIR, File.join(Roast::CACHE_DIR, "sessions"))
    redefine_constant(Roast, :SESSION_DB_PATH, File.join(Roast::CACHE_DIR, "sessions.db"))
  end

  def unstub_xdg_env
    reset_constants
  end
end
