# frozen_string_literal: true

module Roast
  # Handles migration from legacy .roast directories to XDG directories
  module XDGMigration
    class << self
      # Perform automatic migration if legacy .roast directory exists
      def migrate_if_needed(starting_path = Dir.pwd)
        legacy_paths = Roast::XDG.legacy_migration_paths(starting_path)
        return if legacy_paths.empty?

        puts "🔄 Found legacy .roast directory. Migrating to XDG directories..."

        migrate_cache(legacy_paths[:cache]) if legacy_paths[:cache]
        migrate_sessions(legacy_paths[:sessions]) if legacy_paths[:sessions]
        migrate_initializers(legacy_paths[:initializers]) if legacy_paths[:initializers]

        puts "✅ Migration complete! You can safely remove the .roast directory."
        puts "   Legacy directory: #{Roast::XDG.legacy_roast_dir_exists?(starting_path)}"
      end

      private

      def migrate_cache(legacy_cache_dir)
        target_dir = Roast::XDG::Cache.subdir(:functions, gitignored: true)
        migrate_directory(legacy_cache_dir, target_dir, "function cache")
      end

      def migrate_sessions(legacy_sessions_dir)
        target_dir = Roast::XDG::State.subdir(:sessions, gitignored: true)
        migrate_directory(legacy_sessions_dir, target_dir, "session state")
      end

      def migrate_initializers(legacy_initializers_dir)
        target_dir = Roast::XDG::Config.subdir(:initializers)
        migrate_directory(legacy_initializers_dir, target_dir, "initializers")
      end

      def migrate_directory(source_dir, target_dir, description)
        return unless Dir.exist?(source_dir)

        puts "  Migrating #{description}: #{source_dir} → #{target_dir}"

        # Copy all files and subdirectories
        Dir.glob(File.join(source_dir, "**/*"), File::FNM_DOTMATCH).each do |source_path|
          next if File.basename(source_path) == "." || File.basename(source_path) == ".."

          relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(source_dir))
          target_path = File.join(target_dir, relative_path)

          if File.directory?(source_path)
            FileUtils.mkdir_p(target_path) unless File.exist?(target_path)
          else
            FileUtils.mkdir_p(File.dirname(target_path)) unless File.directory?(File.dirname(target_path))
            FileUtils.cp(source_path, target_path) unless File.exist?(target_path)
          end
        end

        puts "    ✓ Migrated #{Dir.glob(File.join(source_dir, "**/*")).count} items"
      rescue => e
        puts "    ⚠️  Error migrating #{description}: #{e.message}"
      end
    end
  end
end
