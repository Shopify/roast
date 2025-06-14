# frozen_string_literal: true

module Roast
  module Workflow
    # Extracts human-readable names from various step types
    class StepNameExtractor
      def extract(step, step_type)
        case step_type
        when StepTypeResolver::COMMAND_STEP
          extract_command_name(step)
        when StepTypeResolver::HASH_STEP
          extract_hash_step_name(step)
        when StepTypeResolver::ITERATION_STEP
          extract_iteration_step_name(step)
        when StepTypeResolver::CONDITIONAL_STEP
          extract_conditional_step_name(step)
        when StepTypeResolver::CASE_STEP
          "case"
        when StepTypeResolver::INPUT_STEP
          "input"
        when StepTypeResolver::AGENT_STEP
          StepTypeResolver.extract_name(step)
        when StepTypeResolver::STRING_STEP
          step.to_s
        else
          step.to_s
        end
      end

      private

      def extract_command_name(step)
        cmd = step.to_s.strip
        cmd.length > 20 ? "#{cmd[0..19]}..." : cmd
      end

      def extract_hash_step_name(step)
        key, value = step.to_a.first

        # Check if this looks like an inline prompt (key is similar to sanitized value)
        if value.is_a?(String)
          # Get first non-empty line
          first_line = value.lines.map(&:strip).find { |line| !line.empty? } || ""

          # If key looks like it was auto-generated from the content, use truncated content
          sanitized = first_line.downcase.gsub(/[^a-z0-9_]/, "_").squeeze("_").gsub(/^_|_$/, "")
          if key.to_s == sanitized || key.to_s.start_with?(sanitized[0..15])
            # This is likely an inline prompt
            first_line.length > 20 ? "#{first_line[0..19]}..." : first_line
          else
            # This is a labeled step
            key.to_s
          end
        else
          key.to_s
        end
      end

      def extract_iteration_step_name(step)
        if step.key?("each")
          items = step["each"]
          count = items.respond_to?(:size) ? items.size : "?"
          "each (#{count} items)"
        elsif step.key?("repeat")
          config = step["repeat"]
          times = config.is_a?(Hash) ? config["times"] || "?" : config
          "repeat (#{times} times)"
        else
          "iteration"
        end
      end

      def extract_conditional_step_name(step)
        if step.key?("if")
          "if"
        elsif step.key?("unless")
          "unless"
        else
          "conditional"
        end
      end
    end
  end
end
