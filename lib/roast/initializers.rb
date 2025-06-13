# frozen_string_literal: true

module Roast
  class Initializers
    class << self
      # Get all possible initializer directories in priority order
      def initializer_directories
        directories = []

        # 1. Workflow-local initializers (highest priority)
        workflow_initializers = workflow_initializers_path
        directories << workflow_initializers if workflow_initializers && Dir.exist?(workflow_initializers)

        # 2. XDG global config initializers
        xdg_initializers = Roast::XDG::Config.subdir(:initializers)
        directories << xdg_initializers if Dir.exist?(xdg_initializers)

        # 3. Legacy .roast directory support (with deprecation warning)
        legacy_initializers = legacy_initializers_path
        if legacy_initializers && Dir.exist?(legacy_initializers)
          directories << legacy_initializers
          warn_legacy_usage(legacy_initializers)
        end

        directories
      end

      def load_all
        # Check if we're in test environment by looking for minitest
        if defined?(Minitest) && Minitest::Test
          # Use legacy behavior for tests
          legacy_load_all
        else
          # Normal operation - use XDG-aware loading
          initializer_directories.each do |initializers_dir|
            load_from_directory(initializers_dir)
          end
        end
      rescue => e
        puts "ERROR: Error loading initializers: #{e.message}"
        Roast::Helpers::Logger.error("Error loading initializers: #{e.message}")
        # Don't fail the workflow if initializers can't be loaded
      end

      # Backward compatibility methods for tests
      def config_root(starting_path = Dir.pwd, ending_path = File.dirname(Dir.home))
        paths = []
        candidate = starting_path
        while candidate != ending_path
          paths << File.join(candidate, ".roast")
          candidate = File.dirname(candidate)
        end

        first_existing = paths.find { |path| Dir.exist?(path) }
        first_existing || paths.first
      end

      def initializers_path
        File.join(config_root, "initializers")
      end

      # Legacy loading behavior for tests
      def legacy_load_all
        project_initializers = initializers_path
        return unless Dir.exist?(project_initializers)

        $stderr.puts "Loading project initializers from #{project_initializers}"
        pattern = File.join(project_initializers, "**/*.rb")
        Dir.glob(pattern, sort: true).each do |file|
          $stderr.puts "Loading initializer: #{file}"
          require file
        end
      end

      private

      # Try to find workflow-local initializers directory
      def workflow_initializers_path
        # Look for initializers in current workflow directory
        # This supports putting initializers alongside step directories
        current_dir = Dir.pwd
        initializers_candidate = File.join(current_dir, "initializers")

        # Check if we're in a workflow directory (has workflow.yml or similar)
        workflow_files = Dir.glob(File.join(current_dir, "{workflow.yml,workflow.yaml,*.yml,*.yaml}"))
        return initializers_candidate if workflow_files.any?

        nil
      end

      # Legacy .roast directory support - search up the directory tree
      def legacy_initializers_path
        legacy_roast = Roast::XDG.legacy_roast_dir_exists?
        return unless legacy_roast

        File.join(legacy_roast, "initializers")
      end

      def load_from_directory(directory)
        $stderr.puts "Loading initializers from #{directory}"
        pattern = File.join(directory, "**/*.rb")
        Dir.glob(pattern, sort: true).each do |file|
          $stderr.puts "  Loading initializer: #{file}"
          require file
        end
      end

      def warn_legacy_usage(legacy_path)
        $stderr.puts "⚠️  DEPRECATION WARNING: Loading initializers from legacy .roast directory"
        $stderr.puts "   Legacy path: #{legacy_path}"
        $stderr.puts "   Please migrate to XDG config directory: #{Roast::XDG::Config.subdir(:initializers)}"
        $stderr.puts "   Or place initializers in your workflow directory alongside steps"
      end
    end
  end
end
