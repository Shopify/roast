# frozen_string_literal: true

module Roast
  module Workflow
    module Testing
      # Coverage tracking for workflow steps
      class StepCoverage
        class << self
          def start_tracking
            @coverage_data ||= {}
            @tracking_enabled = true
          end

          def stop_tracking
            @tracking_enabled = false
          end

          def reset
            @coverage_data = {}
          end

          def record_step_execution(step_class, method_name = :call)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            @coverage_data[step_name] ||= {
              executions: 0,
              methods: {},
              branches: {},
              prompts: {},
              tools_used: Set.new,
              models_used: Set.new,
              execution_paths: [],
            }

            @coverage_data[step_name][:executions] += 1
            @coverage_data[step_name][:methods][method_name] ||= 0
            @coverage_data[step_name][:methods][method_name] += 1
          end

          def record_branch_taken(step_class, branch_id, condition_met)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            return unless @coverage_data[step_name]

            @coverage_data[step_name][:branches][branch_id] ||= {
              true => 0,
              false => 0,
            }
            @coverage_data[step_name][:branches][branch_id][condition_met] += 1
          end

          def record_prompt_used(step_class, prompt_file)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            return unless @coverage_data[step_name]

            @coverage_data[step_name][:prompts][prompt_file] ||= 0
            @coverage_data[step_name][:prompts][prompt_file] += 1
          end

          def record_tool_usage(step_class, tool_name)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            return unless @coverage_data[step_name]

            @coverage_data[step_name][:tools_used] << tool_name
          end

          def record_model_usage(step_class, model_name)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            return unless @coverage_data[step_name]

            @coverage_data[step_name][:models_used] << model_name
          end

          def record_execution_path(step_class, path_id)
            return unless @tracking_enabled

            step_name = step_class.name
            @coverage_data ||= {}
            return unless @coverage_data[step_name]

            @coverage_data[step_name][:execution_paths] << path_id
          end

          def generate_report
            return "No coverage data collected" unless @coverage_data&.any?

            report = []
            report << "=== Step Coverage Report ==="
            report << "Total Steps Tested: #{@coverage_data.size}"
            report << ""

            @coverage_data.each do |step_name, data|
              report << "Step: #{step_name}"
              report << "  Executions: #{data[:executions]}"

              # Method coverage
              if data[:methods].any?
                report << "  Methods called:"
                data[:methods].each do |method, count|
                  report << "    #{method}: #{count} times"
                end
              end

              # Branch coverage
              if data[:branches].any?
                report << "  Branch coverage:"
                data[:branches].each do |branch_id, results|
                  true_count = results[true] || 0
                  false_count = results[false] || 0
                  total = true_count + false_count
                  coverage_pct = total > 0 ? ((results.keys.size.to_f / 2) * 100).round(1) : 0
                  report << "    #{branch_id}: #{coverage_pct}% (true: #{true_count}, false: #{false_count})"
                end
              end

              # Prompt coverage
              if data[:prompts].any?
                report << "  Prompts used:"
                data[:prompts].each do |prompt, count|
                  report << "    #{prompt}: #{count} times"
                end
              end

              # Tool usage
              if data[:tools_used].any?
                report << "  Tools used: #{data[:tools_used].to_a.join(", ")}"
              end

              # Model usage
              if data[:models_used].any?
                report << "  Models used: #{data[:models_used].to_a.join(", ")}"
              end

              # Execution paths
              if data[:execution_paths].any?
                unique_paths = data[:execution_paths].uniq.size
                report << "  Unique execution paths: #{unique_paths}"
              end

              report << ""
            end

            # Summary statistics
            report << "=== Summary ==="
            total_executions = @coverage_data.values.sum { |d| d[:executions] }
            report << "Total Step Executions: #{total_executions}"

            all_tools = @coverage_data.values.flat_map { |d| d[:tools_used].to_a }.uniq
            report << "Unique Tools Used: #{all_tools.size}"

            all_models = @coverage_data.values.flat_map { |d| d[:models_used].to_a }.uniq
            report << "Unique Models Used: #{all_models.size}"

            # Calculate overall branch coverage
            total_branches = 0
            covered_branches = 0
            @coverage_data.values.each do |data|
              data[:branches].each do |_, results|
                total_branches += 2 # Each branch has true/false
                covered_branches += results.keys.size
              end
            end

            if total_branches > 0
              branch_coverage_pct = ((covered_branches.to_f / total_branches) * 100).round(1)
              report << "Overall Branch Coverage: #{branch_coverage_pct}%"
            end

            report.join("\n")
          end

          def coverage_percentage
            return 0.0 unless @coverage_data&.any?

            total_possible = 0
            total_covered = 0

            @coverage_data.each do |_, data|
              # Count executions
              total_possible += 1
              total_covered += 1 if data[:executions] > 0

              # Count branches
              data[:branches].each do |_, results|
                total_possible += 2 # true and false paths
                total_covered += 1 if results[true] && results[true] > 0
                total_covered += 1 if results[false] && results[false] > 0
              end
            end

            return 100.0 if total_possible == 0

            ((total_covered.to_f / total_possible) * 100).round(1)
          end

          def uncovered_branches
            uncovered = []

            @coverage_data.each do |step_name, data|
              data[:branches].each do |branch_id, results|
                uncovered << "#{step_name}##{branch_id}:true" unless results[true]&.positive?
                uncovered << "#{step_name}##{branch_id}:false" unless results[false]&.positive?
              end
            end

            uncovered
          end

          def to_json
            {
              coverage_data: @coverage_data,
              summary: {
                total_steps: @coverage_data.size,
                total_executions: @coverage_data.values.sum { |d| d[:executions] },
                coverage_percentage: coverage_percentage,
                uncovered_branches: uncovered_branches,
              },
            }.to_json
          end
        end
      end

      # Module to be included in steps for automatic coverage tracking
      module CoverageTracking
        class << self
          def included(base)
            base.class_eval do
              # Store original method reference
              alias_method(:call_without_coverage, :call)

              # Override call method
              define_method(:call) do
                StepCoverage.record_step_execution(self.class, :call)
                StepCoverage.record_model_usage(self.class, model) if respond_to?(:model)

                result = call_without_coverage

                # Record any tools used during execution
                if defined?(@workflow) && @workflow.respond_to?(:chat_completion_calls)
                  @workflow.chat_completion_calls.each do |call|
                    call[:tools]&.each { |tool| StepCoverage.record_tool_usage(self.class, tool) }
                  end
                end

                result
              end
            end
          end
        end
      end
    end
  end
end
