# frozen_string_literal: true

module Roast
  module XDGMigration
    class << self
      # Handles migration from legacy .roast directories to XDG directories
      def migrate_if_needed
        legacy_paths = legacy_migration_paths
        return if legacy_paths.empty?

        Roast::Helpers::Logger.info("🔄 Found legacy .roast directory. Migrating to XDG directories...")

        migrate_cache(legacy_paths[:cache]) if legacy_paths[:cache]
        migrate_sessions(legacy_paths[:sessions]) if legacy_paths[:sessions]
        migrate_initializers(legacy_paths[:initializers]) if legacy_paths[:initializers]
        migrate_sessions_db(legacy_paths[:sessions_db]) if legacy_paths[:sessions_db]

        Roast::Helpers::Logger.info("✅ Migration complete! You can safely remove the .roast directory: #{legacy_dot_roast_dir}")
      end

      def warn_legacy_initializers_usage(legacy_paths)
        Roast::Helpers::Logger.warn(<<~DEPRECATION.chomp)
          ⚠️  DEPRECATION WARNING:
          Loading initializers from legacy .roast directory
          Paths:
            #{legacy_paths.join("\n     ")}
          Please migrate to your workflow directory: workflow_dir/initializers
          Or use the global XDG config directory: #{GLOBAL_INITIALIZERS_DIR}
          See the README for more details: https://github.com/Shopify/roast/blob/main/README.md#project-specific-configuration
        DEPRECATION
      end

      # Get migration data from legacy .roast directory
      def legacy_migration_paths
        legacy_roast = legacy_dot_roast_dir
        return {} unless legacy_roast

        {
          cache: File.join(legacy_roast, "cache"),
          sessions: File.join(legacy_roast, "sessions"),
          initializers: File.join(legacy_roast, "initializers"),
          # sessions.db is either here or at the path specified by ROAST_SESSIONS_DB
          # We still support ROAST_SESSIONS_DB, so we only migrate it if its under home.
          sessions_db: File.expand_path("~/.roast/sessions.db"),
        }.select { |_, path| File.exist?(path) }
      end

      # Find legacy .roast directory by searching up the directory tree
      def legacy_dot_roast_dir(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        candidate = starting_path

        until candidate == ending_path || candidate == "/"
          dot_roast_candidate = File.join(candidate, ".roast")
          return dot_roast_candidate if Dir.exist?(dot_roast_candidate)

          candidate = File.dirname(candidate)
        end

        # The original functionality was to offer a .roast directory in the starting path,
        # if we can't find an existing one expecting caller to create it anew.
        # We no longer need to create it, so we return nil if we don't find one.
        nil
      end

      def legacy_initializers_path
        legacy_migration_paths.fetch(:initializers, nil)
      end

      def legacy_sessions_db_path
        legacy_migration_paths.fetch(:sessions_db, nil)
      end

      private

      def migrate_cache(legacy_cache_dir)
        migrate_directory(legacy_cache_dir, FUNCTION_CACHE_DIR, "function cache")
      end

      def migrate_sessions(legacy_sessions_dir)
        migrate_directory(legacy_sessions_dir, SESSION_DATA_DIR, "session state")
      end

      def migrate_initializers(legacy_initializers_dir, workflow_context_path = Dir.pwd)
        # Migrate to workflow-local initializers directory, not global XDG directory
        workflow_initializers_dir = File.join(workflow_context_path, "initializers")
        migrate_directory(legacy_initializers_dir, workflow_initializers_dir, "initializers")
      end

      def migrate_sessions_db(legacy_sessions_db_path)
        migrate_file(legacy_sessions_db_path, SESSION_DB_PATH, "session database")
      end

      def migrate_directory(source_dir, target_dir, description)
        return unless Dir.exist?(source_dir)

        Roast::Helpers::Logger.info("Migrating #{description}: #{source_dir} → #{target_dir}")

        # Copy all files and subdirectories
        Dir.glob(File.join(source_dir, "**/*"), File::FNM_DOTMATCH).each do |source_path|
          next if File.basename(source_path) == "." || File.basename(source_path) == ".."

          relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(source_dir))
          target_path = File.join(target_dir, relative_path)

          if File.directory?(source_path)
            FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
          else
            FileUtils.mkdir_p(File.dirname(target_path)) unless Dir.exist?(File.dirname(target_path))
            FileUtils.cp(source_path, target_path) unless File.exist?(target_path)
          end
        end

        Roast::Helpers::Logger.info("✓ Migrated #{Dir.glob(File.join(source_dir, "**/*")).count} items from #{source_dir}")
        Roast::Helpers::Logger.info("✓ You can safely delete this directory: #{source_dir}")
      rescue => e
        Roast::Helpers::Logger.error("⚠️  Error migrating #{description}: #{e.message}")
      end

      def migrate_file(source_path, target_path, description)
        return unless File.exist?(source_path)

        Roast::Helpers::Logger.info("Migrating #{description}: #{source_path} → #{target_path}")
        FileUtils.mkdir_p(File.dirname(target_path)) unless File.directory?(File.dirname(target_path))
        FileUtils.cp(source_path, target_path) unless File.exist?(target_path)
      end
    end
  end
end
