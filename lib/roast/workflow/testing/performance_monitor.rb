# frozen_string_literal: true

module Roast
  module Workflow
    module Testing
      # Performance monitoring for step execution using ActiveSupport instrumentation
      class PerformanceMonitor
        attr_reader :metrics

        def initialize
          @metrics = {
            executions: [],
            api_calls: [],
            tool_calls: [],
            memory_usage: [],
          }
          @subscribers = []
          setup_subscribers
        end

        # Start monitoring a step execution
        def start_monitoring
          @start_time = Time.now
          @start_allocations = GC.stat[:total_allocated_objects] if GC.respond_to?(:stat)
          @api_call_count = 0
          @tool_call_count = 0
        end

        # Record an API call
        def record_api_call(model, tokens_used = nil)
          @api_call_count += 1
          # Also instrument the call
          ActiveSupport::Notifications.instrument("roast.api.call", model: model, tokens_used: tokens_used)
        end

        # Record a tool call
        def record_tool_call(tool_name, execution_time = nil)
          @tool_call_count += 1
          # Also instrument the call
          ActiveSupport::Notifications.instrument("roast.tool.execute", tool_name: tool_name, execution_time: execution_time)
        end

        # Complete monitoring and record final metrics
        def complete_monitoring(result = nil)
          execution_time = Time.now - @start_time
          allocations = @start_allocations ? GC.stat[:total_allocated_objects] - @start_allocations : 0

          execution_metrics = {
            timestamp: @start_time,
            execution_time: execution_time,
            memory_delta: allocations,
            api_calls: @api_call_count,
            tool_calls: @tool_call_count,
            success: !result.nil?,
            result_size: result_size(result),
          }

          @metrics[:executions] << execution_metrics
          @metrics[:memory_usage] << {
            timestamp: Time.now,
            usage: allocations,
          }

          execution_metrics
        end

        # Generate performance report
        def generate_report
          return "No executions recorded" if @metrics[:executions].empty?

          executions = @metrics[:executions]

          report = []
          report << "=== Performance Report ==="
          report << "Total Executions: #{executions.size}"
          report << ""

          # Execution time statistics
          execution_times = executions.map { |e| e[:execution_time] }
          report << "Execution Time:"
          report << "  Average: #{format_time(execution_times.sum / execution_times.size)}"
          report << "  Min: #{format_time(execution_times.min)}"
          report << "  Max: #{format_time(execution_times.max)}"
          report << ""

          # API call statistics from instrumentation
          total_api_calls = executions.sum { |e| e[:api_calls] }
          report << "API Calls:"
          report << "  Total: #{total_api_calls}"
          report << "  Average per execution: #{(total_api_calls.to_f / executions.size).round(2)}"
          report << ""

          # Tool call statistics from instrumentation
          total_tool_calls = executions.sum { |e| e[:tool_calls] }
          report << "Tool Calls:"
          report << "  Total: #{total_tool_calls}"
          report << "  Average per execution: #{(total_tool_calls.to_f / executions.size).round(2)}"

          if @metrics[:tool_calls].any?
            tool_breakdown = @metrics[:tool_calls].group_by { |tc| tc[:tool] }
            report << "  Breakdown by tool:"
            tool_breakdown.each do |tool, calls|
              report << "    #{tool}: #{calls.size} calls"
            end
          end
          report << ""

          # Memory usage statistics
          memory_deltas = executions.map { |e| e[:memory_delta] }.compact
          if memory_deltas.any?
            report << "Memory Usage:"
            report << "  Average delta: #{format_memory(memory_deltas.sum / memory_deltas.size)}"
            report << "  Max delta: #{format_memory(memory_deltas.max)}"
          end

          report.join("\n")
        end

        # Check if performance meets thresholds
        def meets_threshold?(thresholds = {})
          return true if @metrics[:executions].empty?

          last_execution = @metrics[:executions].last

          thresholds.all? do |metric, threshold|
            case metric
            when :execution_time
              last_execution[:execution_time] <= threshold
            when :memory_delta
              last_execution[:memory_delta] <= threshold
            when :api_calls
              last_execution[:api_calls] <= threshold
            when :tool_calls
              last_execution[:tool_calls] <= threshold
            else
              true
            end
          end
        end

        # Get performance trends over multiple executions
        def performance_trends
          return {} if @metrics[:executions].size < 2

          executions = @metrics[:executions]

          trends = {}

          # Execution time trend
          execution_times = executions.map { |e| e[:execution_time] }
          trends[:execution_time] = calculate_trend(execution_times)

          # API calls trend
          api_calls = executions.map { |e| e[:api_calls] }
          trends[:api_calls] = calculate_trend(api_calls)

          # Memory usage trend
          memory_deltas = executions.map { |e| e[:memory_delta] }.compact
          trends[:memory_usage] = calculate_trend(memory_deltas) if memory_deltas.size >= 2

          trends
        end

        # Clean up subscribers
        def cleanup
          @subscribers.each do |subscriber|
            ActiveSupport::Notifications.unsubscribe(subscriber)
          end
          @subscribers.clear
        end

        private

        def setup_subscribers
          # Subscribe to tool execution events
          @subscribers << ActiveSupport::Notifications.subscribe("roast.tool.execute") do |_name, start, finish, _id, payload|
            @metrics[:tool_calls] << {
              timestamp: start,
              tool: payload[:tool_name] || payload[:tool],
              execution_time: payload[:execution_time] || (finish - start),
            }
          end

          # Subscribe to tool completion events (if additional data is needed)
          @subscribers << ActiveSupport::Notifications.subscribe("roast.tool.complete") do |name, start, finish, id, payload|
            # Additional tool completion handling if needed
          end

          # Subscribe to API calls (assuming we instrument these)
          @subscribers << ActiveSupport::Notifications.subscribe("roast.api.call") do |_name, start, finish, _id, payload|
            @metrics[:api_calls] << {
              timestamp: start,
              model: payload[:model],
              tokens_used: payload[:tokens_used],
              response_time: finish - start,
            }
          end
        end

        def result_size(result)
          case result
          when String
            result.bytesize
          when Hash, Array
            result.to_json.bytesize
          else
            result.to_s.bytesize
          end
        rescue
          0
        end

        def format_time(seconds)
          if seconds < 0.001
            "#{(seconds * 1_000_000).round(2)}μs"
          elsif seconds < 1
            "#{(seconds * 1000).round(2)}ms"
          else
            "#{seconds.round(2)}s"
          end
        end

        def format_memory(bytes)
          if bytes < 1024
            "#{bytes}B"
          elsif bytes < 1024 * 1024
            "#{(bytes / 1024.0).round(2)}KB"
          else
            "#{(bytes / (1024.0 * 1024.0)).round(2)}MB"
          end
        end

        def calculate_trend(values)
          return :stable if values.size < 2

          # Simple linear regression to determine trend
          n = values.size
          x_values = (0...n).to_a

          x_mean = x_values.sum.to_f / n
          y_mean = values.sum.to_f / n

          numerator = x_values.zip(values).sum { |x, y| (x - x_mean) * (y - y_mean) }
          denominator = x_values.sum { |x| (x - x_mean)**2 }

          slope = denominator == 0 ? 0 : numerator / denominator

          # Determine trend based on slope relative to mean
          relative_slope = y_mean == 0 ? 0 : slope / y_mean

          if relative_slope > 0.1
            :increasing
          elsif relative_slope < -0.1
            :decreasing
          else
            :stable
          end
        end
      end
    end
  end
end
