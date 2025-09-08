# typed: true
# frozen_string_literal: true

module Roast
  module ValueObjects
    # Value object representing a workflow file path with validation and resolution
    class WorkflowPath
      class InvalidPathError < Roast::Error; end

      attr_reader :value

      def initialize(path)
        @value = normalize_path(path)
        @pathname = Pathname.new(@value)
        validate!
        freeze
      end

      def exist?
        pathname.exist?
      end

      def absolute?
        pathname.absolute?
      end

      def relative?
        pathname.relative?
      end

      def dirname
        pathname.dirname.to_s
      end

      def basename
        pathname.basename.to_s
      end

      def to_s
        @value
      end

      def to_path
        @value
      end

      def ==(other)
        return false unless other.is_a?(WorkflowPath)

        value == other.value
      end
      alias_method :eql?, :==

      def hash
        [self.class, @value].hash
      end

      private

      attr_reader :pathname

      def normalize_path(path)
        path.to_s.strip
      end

      def validate!
        raise InvalidPathError, "Workflow path cannot be empty" if @value.empty?
        raise InvalidPathError, "Workflow path must have .yml or .yaml extension" unless valid_extension?
      end

      def valid_extension?
        @value.end_with?(".yml") || @value.end_with?(".yaml")
      end
    end
  end
end
