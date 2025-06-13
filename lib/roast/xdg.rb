# frozen_string_literal: true

module Roast
  # XDG Base Directory Specification implementation for Roast
  # Provides standardized locations for configuration, cache, and state data
  module XDG
    class << self
      # XDG Base Directory paths with sensible defaults
      def config_home
        ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))
      end

      def cache_home
        ENV.fetch("XDG_CACHE_HOME", File.join(Dir.home, ".cache"))
      end

      def state_home
        ENV.fetch("XDG_STATE_HOME", File.join(Dir.home, ".local", "state"))
      end

      # Ensure a directory exists, creating it if necessary
      # Optionally adds a .gitignore file to ignore all contents
      def ensure_dir(path, gitignored: false)
        FileUtils.mkdir_p(path) unless File.directory?(path)

        if gitignored
          gitignore_path = File.join(path, ".gitignore")
          File.write(gitignore_path, "*\n") unless File.exist?(gitignore_path)
        end

        path
      end

      # Migration helper - check if old .roast directory exists
      def legacy_roast_dir_exists?(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        candidate = starting_path

        until candidate == ending_path || candidate == "/"
          dot_roast_candidate = File.join(candidate, ".roast")
          return dot_roast_candidate if Dir.exist?(dot_roast_candidate)

          candidate = File.dirname(candidate)
        end

        false
      end

      # Get migration data from legacy .roast directory
      def legacy_migration_paths(starting_path = Dir.pwd)
        legacy_roast = legacy_roast_dir_exists?(starting_path)
        return {} unless legacy_roast

        {
          cache: File.join(legacy_roast, "cache"),
          sessions: File.join(legacy_roast, "sessions"),
          initializers: File.join(legacy_roast, "initializers"),
        }.select { |_, path| Dir.exist?(path) }
      end
    end

    # XDG Config directory manager
    module Config
      class << self
        def root
          File.join(Roast::XDG.config_home, "roast")
        end

        def subdir(name, gitignored: false)
          path = File.join(root, name.to_s)
          Roast::XDG.ensure_dir(path, gitignored: gitignored)
        end
      end
    end

    # XDG Cache directory manager
    module Cache
      class << self
        def root
          File.join(Roast::XDG.cache_home, "roast")
        end

        def subdir(name, gitignored: true)
          path = File.join(root, name.to_s)
          Roast::XDG.ensure_dir(path, gitignored: gitignored)
        end
      end
    end

    # XDG State directory manager
    module State
      class << self
        def root
          File.join(Roast::XDG.state_home, "roast")
        end

        def subdir(name, gitignored: true)
          path = File.join(root, name.to_s)
          Roast::XDG.ensure_dir(path, gitignored: gitignored)
        end
      end
    end
  end
end
