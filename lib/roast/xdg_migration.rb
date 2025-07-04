# frozen_string_literal: true

module Roast
  module XDGMigration
    class << self
      # Shows deprecation warnings for legacy .roast directories without migrating
      def warn_if_migration_needed(workflow_path = nil)
        workflow_context_path = extract_context_path(workflow_path)
        migratables = migratables(workflow_context_path)
        return if migratables.empty?

        migration_strings = migratables.values.map do |migratable|
          "{{yellow:#{migratable[:source]}}} -> {{blue:#{migratable[:target]}}}" if migratable_whole?(migratable)
        end.compact

        Roast::Helpers::Logger.warn(::CLI::UI.fmt(<<~DEPRECATION.chomp))
          {{yellow:⚠️  DEPRECATION WARNING:}}
          Found legacy .roast directories that should be migrated to XDG directories:
          #{migration_strings.join("\n")}

          {{bold:Please run:}} {{cyan:roast xdg-migrate}} {{bold:to migrate your data}}

          Legacy .roast directories are deprecated and support will be removed in a future version.
        DEPRECATION
      end

      # Handles migration from legacy .roast directories to XDG directories
      def migrate(workflow_context_path = nil, auto_confirm = false)
        migratables = migratables(workflow_context_path)
        return if migratables.empty?

        migration_strings = migratables.values.map do |migratable|
          "{{yellow:#{migratable[:source]}}} -> {{blue:#{migratable[:target]}}}" if migratable.key?(:target) && migratable.key?(:source)
        end.compact

        Roast::Helpers::Logger.info("Found legacy .roast directory")
        migration_strings.each do |migration_string|
          Roast::Helpers::Logger.info(migration_string)
        end

        return unless auto_confirm || ::CLI::UI::Prompt.confirm("Would you like to migrate these directories?")

        migratables.values.each do |migratable|
          migrate_migratable(migratable, auto_confirm) if migratable_whole?(migratable)
        end

        return unless auto_confirm || ::CLI::UI::Prompt.confirm("Would you like to delete the legacy directories?")

        FileUtils.rm_rf(migratables.values.map { |migratable| migratable[:source] })

        Roast::Helpers::Logger.info("Migration complete!")
      end

      def migratables(workflow_context_path = nil)
        legacy_roast = legacy_dot_roast_dir
        return {} unless legacy_roast

        paths = {
          cache: {
            source: File.join(legacy_roast, "cache"),
            target: FUNCTION_CACHE_DIR,
            description: "function cache",
            type: :directory,
          },
          sessions: {
            source: File.join(legacy_roast, "sessions"),
            target: SESSION_DATA_DIR,
            description: "session state",
            type: :directory,
          },
          sessions_db_home: {
            source: File.expand_path("~/.roast/sessions.db"),
            target: SESSION_DB_PATH,
            description: "session database",
            type: :file,
          },
          sessions_db_local: {
            source: File.join(legacy_roast, "sessions.db"),
            target: SESSION_DB_PATH,
            description: "session database",
            type: :file,
          },
          initializers: {
            source: File.join(legacy_roast, "initializers"),
            description: "initializers",
            type: :directory,
          },
        }

        if workflow_context_path
          paths[:initializers][:target] = File.join(workflow_context_path, "initializers")
        end

        paths.select { |_, path| File.exist?(path[:source]) }
      end

      def migratable_whole?(migratable)
        migratable.key?(:target)
      end

      # def always_migratable_paths
      #   # We can't migrate initializers without knowing the workflow context path.
      #   legacy_migration_paths.reject { |k, _| k == :initializers }
      # end

      # # Get migration data from legacy .roast directory
      # def legacy_migration_paths
      #   legacy_roast = legacy_dot_roast_dir
      #   return {} unless legacy_roast

      #   {
      #     cache: File.join(legacy_roast, "cache"),
      #     sessions: File.join(legacy_roast, "sessions"),
      #     initializers: File.join(legacy_roast, "initializers"),

      #     # sessions.db is either here or at the path specified by ROAST_SESSIONS_DB
      #     # We still support ROAST_SESSIONS_DB, so we only migrate it if its under home.
      #     sessions_db: File.expand_path("~/.roast/sessions.db"),
      #   }.select { |_, path| File.exist?(path) }
      # end

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

      def legacy_sessions_db_path
        home_path = migratables.dig(:sessions_db_home, :source)
        local_path = migratables.dig(:sessions_db_local, :source)

        return home_path if home_path && File.exist?(home_path)
        return local_path if local_path && File.exist?(local_path)

        nil
      end

      def legacy_initializers
        legacy_initializers_path = migratables.dig(:initializers, :source)
        return [] unless legacy_initializers_path && Dir.exist?(legacy_initializers_path)

        legacy_initializer_files = Dir.glob(File.join(legacy_initializers_path, "**/*.rb"))
        unless legacy_initializer_files.empty?
          Roast::Helpers::Logger.warn(::CLI::UI.fmt("{{yellow:⚠️  DEPRECATION WARNING:}} Legacy initializers found in #{legacy_initializers_path}. Please run {{cyan:roast xdg-migrate}} to migrate to XDG directories."))
        end

        legacy_initializer_files
      end

      private

      def extract_context_path(workflow_path)
        return if workflow_path.nil?

        if workflow_path.end_with?("workflow.yml")
          File.dirname(workflow_path)
        else
          workflow_path
        end
      end

      def migrate_migratable(migratable, auto_confirm = false)
        case migratable[:type]
        when :directory
          migrate_directory(migratable[:source], migratable[:target], migratable[:description], auto_confirm)
        when :file
          migrate_file(migratable[:source], migratable[:target], migratable[:description], auto_confirm)
        end
      end

      def migrate_cache(legacy_cache_dir)
        migrate_directory(legacy_cache_dir, FUNCTION_CACHE_DIR, "function cache")
      end

      def migrate_sessions(legacy_sessions_dir)
        migrate_directory(legacy_sessions_dir, SESSION_DATA_DIR, "session state")
      end

      def migrate_sessions_db(legacy_sessions_db_path)
        migrate_file(legacy_sessions_db_path, SESSION_DB_PATH, "session database")
      end

      def migrate_directory(source_dir, target_dir, description, auto_confirm = false)
        return unless Dir.exist?(source_dir)

        Roast::Helpers::Logger.info("Migrating #{description}")
        Roast::Helpers::Logger.info("Migrating: #{source_dir} → #{target_dir}")

        # Copy all files and subdirectories
        Dir.glob(File.join(source_dir, "**/*"), File::FNM_DOTMATCH).each do |source_path|
          next if File.basename(source_path) == "." || File.basename(source_path) == ".."

          relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(source_dir))
          target_path = File.join(target_dir, relative_path)

          if File.directory?(source_path)
            FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
          else
            FileUtils.mkdir_p(File.dirname(target_path)) unless Dir.exist?(File.dirname(target_path))

            if File.exist?(target_path)
              overwrite_msg = "File already exists at #{target_path}. Do you want to overwrite it?"
              next unless ::CLI::UI::Prompt.confirm(overwrite_msg)
            end

            FileUtils.cp(source_path, target_path)
          end
        end

        Roast::Helpers::Logger.info("✓ Migrated #{Dir.glob(File.join(source_dir, "**/*")).count} items from #{source_dir}")
        Roast::Helpers::Logger.info("✓ You can safely delete this directory: #{source_dir}")
      rescue => e
        Roast::Helpers::Logger.error("⚠️  Error migrating #{description}: #{e.message}")
      end

      def migrate_file(source_path, target_path, description, auto_confirm = false)
        return unless File.exist?(source_path)

        Roast::Helpers::Logger.info("Migrating #{description}")
        Roast::Helpers::Logger.info("Migrating #{description}: #{source_path} → #{target_path}")
        FileUtils.mkdir_p(File.dirname(target_path)) unless File.directory?(File.dirname(target_path))

        if File.exist?(target_path)
          overwrite_msg = "File already exists at #{target_path}. Do you want to overwrite it?"
          return unless ::CLI::UI::Prompt.confirm(overwrite_msg)
        end

        FileUtils.cp(source_path, target_path)
      end
    end
  end
end
