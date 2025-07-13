# frozen_string_literal: true

module Roast
  module Helpers
    module MetadataAccess
      def step_metadata(step_name = nil)
        step_name ||= current_step_name
        return {} unless step_name

        metadata = workflow_metadata || {}
        metadata[step_name] || {}
      end

      def set_current_step_metadata(key, value)
        step_name = current_step_name
        metadata = workflow_metadata

        return unless step_name && metadata

        metadata[step_name] ||= {}
        metadata[step_name][key] = value
      end

      private

      def workflow_metadata
        metadata = Thread.current[:workflow_metadata]
        Roast::Helpers::Logger.warn("MetadataAccess#workflow_metadata is not present") if metadata.nil?
        metadata
      end

      def current_step_name
        step_name = Thread.current[:current_step_name]
        Roast::Helpers::Logger.warn("MetadataAccess#current_step_name is not present") if step_name.nil?
        step_name
      end
    end
  end
end
