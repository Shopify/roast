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
        initializer_files = []
        # 1. Workflow-local initializers (highest priority)
        local_dir = local_initializers_dir(workflow_context_path)
        if Dir.exist?(local_dir)
          initializer_files.concat(Dir.glob(File.join(local_dir, "**/*.rb")))
        end

        # 2. XDG global config initializers
        if Dir.exist?(Roast::GLOBAL_INITIALIZERS_DIR)
          initializer_files.concat(Dir.glob(File.join(Roast::GLOBAL_INITIALIZERS_DIR, "**/*.rb")))
        end

        # 3. Legacy .roast directory support
        initializer_files.concat(Roast::XDGMigration.new.legacy_initializers)

        unique_initializer_files = initializer_files.uniq { |file| File.basename(file) }

        unique_initializer_files
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
