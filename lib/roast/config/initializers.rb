# frozen_string_literal: true

module Roast
  class Config
    class Initializers
      class << self
        def path
          File.join(Config.root, "initializers")
        end

        def load_all
          project_initializers = path
          return unless Dir.exist?(project_initializers)

          $stderr.puts "Loading project initializers from #{project_initializers}"
          pattern = File.join(project_initializers, "**/*.rb")
          Dir.glob(pattern, sort: true).each do |file|
            $stderr.puts "Loading initializer: #{file}"
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
end
