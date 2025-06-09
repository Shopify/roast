# frozen_string_literal: true

module Roast
  module Workflow
    class Initializers
      class << self
        def path
          File.join(Roast.dot_roast_dir, "initializers")
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
        end
      end
    end
  end
end
