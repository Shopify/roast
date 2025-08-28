# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class << self
        #: (String?) -> void
        def call(file_path = nil, generate_viz: false)
          new(file_path, generate_viz: generate_viz).call
        end
      end

      attr_reader :file_path

      #: (Boolean) -> void
      def initialize(file_path = nil, generate_viz: false)
        @file_path = file_path
        @generate_viz = generate_viz
      end

      #: () -> Boolean
      def generate_viz?
        @generate_viz
      end

      #: () -> String?
      def rube_file_path
        @rube_file_path ||= begin
          options = [@file_path, "rube.rb"].map { |path| File.expand_path(path) }
          options.find { |path| File.exist?(path) }
        end
      end

      #: () -> void
      def call
        if rube_file_path.nil?
          # Rube::Log.puts "Error: No rube.rb file found in current directory"
          # Rube::Log.puts "Usage: rube [path/to/rube_file.rb]"
          Roast::Helpers::Logger.error("No rube.rb file found in current directory")
          Roast::Helpers::Logger.error("Usage: rube [path/to/rube_file.rb]")
          exit(1)
        end

        execute_file
      end

      #: (String) -> void
      def execute_file
        load_all_cogs

        setup_load_path

        load(rube_file_path)
        # rescue Rube::Error => e
        #   # TODO: standardized error handling, maybe?
        #   Rube::Log.puts "Error executing '#{file_path}': #{e} (#{e.class.name})"
        #   Rube::Log.puts "\nFull stack trace:"
        #   Rube::Log.puts e.backtrace&.join("\n") || "No backtrace available"
        #   exit(1)
      end

      #: () -> void
      def load_all_cogs
        Roast::DSL::Cogs.load_all_for(rube_file_path)
      end

      #: () -> void
      def setup_load_path
        # TODO: Load tools from rube/lib.
        rube_lib_dir = File.join(File.dirname(file_path), "rube", "lib")
        $LOAD_PATH.unshift(rube_lib_dir)
      end
    end
  end
end
