# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class << self
        #: (?String?) -> void
        def call(file_path = nil)
          new(file_path).call
        end
      end

      attr_reader :file_path

      #: (?String?) -> void
      def initialize(file_path = nil)
        @file_path = file_path
      end

      #: () -> void
      def call
        if dsl_file_path.nil?
          Roast::Helpers::Logger.error(<<~NO_FILE)
            No roast DSL file found in current directory
          NO_FILE

          exit(1)
        end

        execute_file
      end

      #: () -> String
      def dsl_file_path
        @dsl_file_path ||= begin
          fpath = File.expand_path(@file_path)
          unless File.exist?(fpath)
            raise Roast::Error, "DSL file not found: #{fpath}"
          end

          fpath
        end
      end

      #: () -> void
      def execute_file
        load_all_cogs

        load(dsl_file_path)
      rescue => e
        Roast::Helpers::Logger.error(<<~ERROR)
          #{e.class.name}: #{e.message}
          Backtrace:
          #{e.backtrace&.join("\n")}
        ERROR

        exit(1)
      end

      #: () -> void
      def load_all_cogs
        Roast::DSL::Cogs.load_all_for(dsl_file_path)
      end
    end
  end
end
