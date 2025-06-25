# frozen_string_literal: true

module Roast
  class Initializers
    class << self
      def load_all(workflow_context_path = Dir.pwd)
        # .reverse so we load the highest priority files last, letting them override lower priority files
        initializer_files(workflow_context_path).reverse.each do |file|
          load_initializer(file)
        end
      rescue => e
        puts "ERROR: Error loading initializers: #{e.message}"
        Roast::Helpers::Logger.error("Error loading initializers: #{e.message}")
        # Don't fail the workflow if initializers can't be loaded
      end

      private

      # Get all possible initializer directories in priority order
      def initializer_files(workflow_context_path = Dir.pwd)
        files = []

        # 1. Workflow-local initializers (highest priority)
        local_dir = local_initializers_dir(workflow_context_path)
        if Dir.exist?(local_dir)
          files << Dir.glob(File.join(local_dir, "**/*.rb"))
        end

        # 2. XDG global config initializers
        if Dir.exist?(Roast::GLOBAL_INITIALIZERS_DIR)
          files << Dir.glob(File.join(Roast::GLOBAL_INITIALIZERS_DIR, "**/*.rb"))
        end

        # 3. Legacy .roast directory support (with deprecation warning)
        legacy_initializers = Roast::XDGMigration.legacy_initializers_path
        if legacy_initializers && Dir.exist?(legacy_initializers)
          files << Dir.glob(File.join(legacy_initializers, "**/*.rb"))
          Roast::XDGMigration.warn_legacy_initializers_usage([legacy_initializers])
        end

        # We depend on the files being high to low prio here.
        # .uniq will drop the duplicates after the first it finds, so earlier examples stay.
        files.flatten.uniq { |file| File.basename(file) }
      end

      def local_initializers_dir(workflow_context_path)
        File.join(workflow_context_path, "initializers")
      end

      def load_initializer(file)
        Roast::Helpers::Logger.info("Loading initializer: #{file}")
        require file
      end
    end
  end
end
