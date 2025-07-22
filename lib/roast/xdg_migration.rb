# frozen_string_literal: true

module Roast
  class XDGMigration
    def initialize(dot_roast_path: nil, workflow_context_path: nil, auto_confirm: false)
      @dot_roast_path = dot_roast_path || self.class.find_all_legacy_dot_roast_dirs.first
      @workflow_context_path = workflow_context_path
      @auto_confirm = auto_confirm
    end

    class << self
      # Class method to show warnings for any .roast directories found
      def warn_if_migration_needed(workflow_file_path = nil)
        workflow_context_path = extract_context_path(workflow_file_path)
        migration = new(workflow_context_path:)
        migration.warn_if_migration_needed
      end

      # Find all legacy .roast directories in ancestor tree
      def find_all_legacy_dot_roast_dirs(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        found_dirs = []
        candidate = starting_path

        until candidate == ending_path || candidate == "/"
          dot_roast_candidate = File.join(candidate, ".roast")
          found_dirs << dot_roast_candidate if Dir.exist?(dot_roast_candidate)

          candidate = File.dirname(candidate)
        end

        found_dirs
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
    end

    # Shows deprecation warnings for legacy .roast directories without migrating
    def warn_if_migration_needed
      return unless @dot_roast_path && Dir.exist?(@dot_roast_path)

      return if migratable_candidates.empty?

      Roast::Helpers::Logger.warn(::CLI::UI.fmt(<<~DEPRECATION.chomp))
        {{yellow:⚠️  DEPRECATION WARNING:}}
        Found legacy .roast directory at {{cyan:#{@dot_roast_path}}} that should be migrated to XDG directories:
        #{migration_strings.join("\n")}

        {{bold:Please run:}} {{cyan:roast xdg-migrate #{@workflow_context_path || "/path/to/your/workflow.yml"}}} {{bold:to migrate your data}}

        Legacy .roast directories are deprecated and support will be removed in a future version.
      DEPRECATION
    end

    # Handles migration from legacy .roast directories to XDG directories
    def migrate
      return unless @dot_roast_path && Dir.exist?(@dot_roast_path)

      migrate_legacy_dirs
      cleanup_legacy_dirs
      cleanup_legacy_dot_roast_dir

      if migration_complete?
        Roast::Helpers::Logger.info("Migration complete!")
      else
        unmigrated_candidates = existing_candidates.values.select { |candidate| !candidate_migrated?(candidate) }

        Roast::Helpers::Logger.info(::CLI::UI.fmt(<<~INCOMPLETE.chomp))

          {{yellow:Migration incomplete!}}

          The following items were not migrated:
            {{yellow:#{unmigrated_candidates.map { |candidate| candidate[:source] }.join("\n")}}}
        INCOMPLETE
      end
    end

    def existing_candidates
      @existing_candidates ||= if @dot_roast_path
        candidates.select { |_, candidate| candidate_exists?(candidate) }
      else
        {}
      end
    end

    def migratable_candidates
      @migratable_candidates ||= if @dot_roast_path
        existing_candidates.select { |_, candidate| candidate_migratable?(candidate) }
      else
        {}
      end
    end

    def legacy_sessions_db_path
      candidates&.dig(:sessions_db, :source)
    end

    def legacy_initializers
      # Use existing_candidates instead of migratable_candidates so we find legacy initializers
      # even when they don't have a valid target (no workflow_context_path)
      legacy_initializers_path = existing_candidates&.dig(:initializers, :source)
      return [] unless legacy_initializers_path && Dir.exist?(legacy_initializers_path)

      Dir.glob(File.join(legacy_initializers_path, "**/*.rb"))
    end

    private

    def candidate_exists?(candidate)
      return false unless candidate.key?(:source)

      File.exist?(candidate[:source])
    end

    def candidate_migratable?(candidate)
      return false unless candidate.key?(:target)

      # For directories, only consider migratable if they're not empty
      if candidate[:type] == :directory
        return false if Dir.empty?(candidate[:source])
      end

      true
    end

    def candidates
      return unless @dot_roast_path

      candidates = {
        cache: {
          source: File.join(@dot_roast_path, "cache"),
          target: FUNCTION_CACHE_DIR,
          description: "function cache",
          type: :directory,
        },
        sessions: {
          source: File.join(@dot_roast_path, "sessions"),
          target: SESSION_DATA_DIR,
          description: "session state",
          type: :directory,
        },
        sessions_db: {
          source: File.join(@dot_roast_path, "sessions.db"),
          target: SESSION_DB_PATH,
          description: "session database",
          type: :file,
        },
        initializers: {
          source: File.join(@dot_roast_path, "initializers"),
          description: "initializers",
          type: :directory,
        },
      }

      if @workflow_context_path
        candidates[:initializers][:target] = File.join(@workflow_context_path, "initializers")
      end

      candidates
    end

    def migration_complete?
      existing_candidates.values.all? { |candidate| candidate_migrated?(candidate) }
    end

    def migrated_candidates
      existing_candidates.values.select { |candidate| candidate_migrated?(candidate) }
    end

    def candidate_migrated?(candidate)
      return false unless candidate.key?(:target) && File.exist?(candidate[:target])

      # For each item in the source, check if it exists in the target
      Dir.glob(File.join(candidate[:source], "**/*"), File::FNM_DOTMATCH).all? do |source_path|
        target_path = File.join(candidate[:target], Pathname.new(source_path).relative_path_from(Pathname.new(candidate[:source])))
        File.exist?(target_path)
      end
    end

    def migration_strings
      migratable_candidates.values.map { |candidate| candidate_to_s(candidate) }
    end

    def candidate_to_s(candidate)
      ::CLI::UI.fmt(<<~FROM_TO.chomp)
        From: {{yellow:#{candidate[:source]}}}
        To: {{blue:#{candidate[:target]}}}
      FROM_TO
    end

    def migrate_legacy_dirs
      return if migratable_candidates.empty?

      Roast::Helpers::Logger.info(<<~MIGRATING.chomp)
        ---
        Items to migrate:
        #{migration_strings.join("\n")}
      MIGRATING

      return unless @auto_confirm || ::CLI::UI::Prompt.confirm("Would you like to migrate these items?")

      migratable_candidates.values.each do |candidate|
        migrate_candidate(candidate)
      end
    end

    def cleanup_legacy_dirs
      return if migratable_candidates.empty?

      Roast::Helpers::Logger.info(<<~CLEANING.chomp)
        ---
        The following directories have been migrated:
        #{migrated_candidates.map { |candidate| candidate[:source] }.join("\n")}
      CLEANING

      return unless @auto_confirm || ::CLI::UI::Prompt.confirm("Would you like to delete these directories?")

      migrated_candidates.each do |candidate|
        FileUtils.rm_rf(candidate[:source])
      end
    end

    def cleanup_legacy_dot_roast_dir
      return unless @dot_roast_path && Dir.exist?(@dot_roast_path)

      dot_roast_children = Dir.glob(File.join(@dot_roast_path, "*"), File::FNM_DOTMATCH)
      dot_roast_children.reject! { |child| File.basename(child) == "." || File.basename(child) == ".." }

      if dot_roast_children.any? { |child| File.basename(child) == "initializers" }
        Roast::Helpers::Logger.info(::CLI::UI.fmt(<<~INITIALIZERS_FOUND.chomp))
          ---
          Initializers found in {{yellow:#{@dot_roast_path}}}.
          If you still wish to migrate them, you can do so by running:
          {{cyan:roast xdg-migrate #{@workflow_context_path || "/path/to/your/workflow.yml"}}}
        INITIALIZERS_FOUND

        return
      end

      if dot_roast_children.any?
        Roast::Helpers::Logger.info(::CLI::UI.fmt(<<~UNEXPECTED_CHILDREN.chomp))
          ---
          We cannot delete {{yellow:#{@dot_roast_path}}} because it still has some children:
          #{dot_roast_children.map { |child| "  {{yellow:#{child}}}" }.join("\n")}

          You can deal with them manually.
        UNEXPECTED_CHILDREN
      else
        msg = ::CLI::UI.fmt(<<~DELETE_DOT_ROAST.chomp)
          Looks like {{yellow:#{@dot_roast_path}}} is empty.
          Would you like to delete {{yellow:#{@dot_roast_path}}}?
        DELETE_DOT_ROAST

        return unless @auto_confirm || ::CLI::UI::Prompt.confirm(msg)

        FileUtils.rm_rf(@dot_roast_path)
      end
    end

    def migrate_candidate(candidate)
      case candidate[:type]
      when :directory
        Roast::Helpers::Logger.info(<<~MIGRATING.chomp)
          ---
          Migrating #{candidate[:description]}:
          #{candidate_to_s(candidate)}
        MIGRATING

        migrate_directory(candidate[:source], candidate[:target], candidate[:description])
      when :file
        Roast::Helpers::Logger.info(<<~MIGRATING.chomp)
          ---
          Migrating #{candidate[:description]}:
          #{candidate_to_s(candidate)}
        MIGRATING

        migrate_file(candidate[:source], candidate[:target], candidate[:description])
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

    def migrate_directory(source_dir, target_dir, description)
      return unless Dir.exist?(source_dir)

      if Dir.exist?(target_dir) && !Dir.empty?(target_dir)
        overwrite_msg = "Non empty directory already exists at {{blue:#{target_dir}}}. Do you want to overwrite it?"
        return unless @auto_confirm || ::CLI::UI::Prompt.confirm(overwrite_msg)
      end

      # Copy all files and subdirectories
      Dir.glob(File.join(source_dir, "**/*"), File::FNM_DOTMATCH).each do |source_path|
        next if File.basename(source_path) == "." || File.basename(source_path) == ".."

        relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(source_dir))
        target_path = File.join(target_dir, relative_path)

        if File.directory?(source_path)
          FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
        else
          FileUtils.mkdir_p(File.dirname(target_path)) unless Dir.exist?(File.dirname(target_path))
          FileUtils.cp(source_path, target_path)
        end
      end

      Roast::Helpers::Logger.info("✓ Migrated #{Dir.glob(File.join(source_dir, "**/*")).count} items from #{source_dir}")
    rescue => e
      Roast::Helpers::Logger.error("⚠️  Error migrating #{description}: #{e.message}")
    end

    def migrate_file(source_path, target_path, description)
      return unless File.exist?(source_path)

      FileUtils.mkdir_p(File.dirname(target_path)) unless File.directory?(File.dirname(target_path))

      if File.exist?(target_path)
        overwrite_msg = "File already exists at #{target_path}. Do you want to overwrite it?"
        return unless @auto_confirm || ::CLI::UI::Prompt.confirm(overwrite_msg)
      end

      FileUtils.cp(source_path, target_path)
    end
  end
end
