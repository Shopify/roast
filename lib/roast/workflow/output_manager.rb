# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "roast/workflow/dot_access_hash"

module Roast
  module Workflow
    # Manages workflow output, including both the key-value output hash
    # and the final output string/array
    #
    # Thread Safety Note:
    # The underlying ActiveSupport::HashWithIndifferentAccess is not thread-safe
    # for concurrent writes. For typical workflow patterns where each step writes
    # to a unique key, this is generally safe. However, if future workflows involve
    # concurrent writes to the same output key or more complex concurrent modifications,
    # additional synchronization may be required.
    class OutputManager
      def initialize
        @output = ActiveSupport::HashWithIndifferentAccess.new
        @output_wrapper = nil
        @final_output = []
      end

      # Get output wrapped in DotAccessHash for dot notation access
      def output
        @output_wrapper ||= DotAccessHash.new(@output)
      end

      # Set output, ensuring it's always a HashWithIndifferentAccess
      def output=(value)
        @output = if value.is_a?(ActiveSupport::HashWithIndifferentAccess)
          value
        else
          ActiveSupport::HashWithIndifferentAccess.new(value)
        end
        # Reset the wrapper when output changes
        @output_wrapper = nil
      end

      # Append a message to the final output
      def append_to_final_output(message)
        @final_output << message
      end

      # Get the final output as a string
      def final_output
        return @final_output if @final_output.is_a?(String)
        return "" if @final_output.nil?

        # Handle array case (expected normal case)
        if @final_output.respond_to?(:join)
          @final_output.join("\n\n")
        else
          # Handle any other unexpected type by converting to string
          @final_output.to_s
        end
      end

      # Set the final output directly (used when loading from state)
      attr_writer :final_output

      # Get the raw output hash (for internal use)
      def raw_output
        @output
      end

      # Get a snapshot of the current state for persistence
      def to_h
        {
          output: @output.to_h,
          final_output: @final_output,
        }
      end

      # Restore state from a hash
      def from_h(data)
        return unless data

        self.output = data[:output] if data.key?(:output)
        self.final_output = data[:final_output] if data.key?(:final_output)
      end
    end
  end
end
