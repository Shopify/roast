# frozen_string_literal: true

module Roast
  module Workflow
    # Manages workflow metadata, providing a structure parallel to output
    # but specifically for internal metadata that shouldn't be user-facing
    class MetadataManager
      def initialize
        @metadata = ActiveSupport::HashWithIndifferentAccess.new
        @metadata_wrapper = nil
      end

      # Get metadata wrapped in DotAccessHash for dot notation access
      def metadata
        @metadata_wrapper ||= DotAccessHash.new(@metadata)
      end

      # Set metadata, ensuring it's always a HashWithIndifferentAccess
      def metadata=(value)
        @metadata = if value.is_a?(ActiveSupport::HashWithIndifferentAccess)
          value
        else
          ActiveSupport::HashWithIndifferentAccess.new(value)
        end
        # Reset the wrapper when metadata changes
        @metadata_wrapper = nil
      end

      # Get the raw metadata hash (for internal use)
      def raw_metadata
        @metadata
      end

      # Get a snapshot of the current state for persistence
      def to_h
        @metadata.to_h
      end

      # Restore state from a hash
      def from_h(data)
        return unless data

        self.metadata = data
      end
    end
  end
end
