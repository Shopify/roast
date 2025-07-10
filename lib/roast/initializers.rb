# frozen_string_literal: true

module Roast
  class Initializers
    class << self
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
        File.join(Roast::Initializers.config_root, "initializers")
      end

      def load_all(configuration)
        project_initializers = Roast::Initializers.initializers_path
        return unless Dir.exist?(project_initializers)

        if configuration.verbose
          $stderr.puts "Loading project initializers from #{project_initializers}"
        end
        pattern = File.join(project_initializers, "**/*.rb")
        Dir.glob(pattern, sort: true).each do |file|
          if configuration.verbose
            $stderr.puts "Loading initializer: #{file}"
          end
          require file
        end
      rescue => e
        puts "ERROR: Error loading initializers: #{e.message}"
        Roast::Helpers::Logger.error("Error loading initializers: #{e.message}")
        # Don't fail the workflow if initializers can't be loaded
      end
    end
  end
end
