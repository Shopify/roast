# frozen_string_literal: true

require "test_helper"
require "roast/workflow/testing"

module Roast
  module Workflow
    module Testing
      class PerformanceMonitorTest < ActiveSupport::TestCase
        def setup
          @monitor = PerformanceMonitor.new
        end

        test "initializes with empty metrics" do
          assert_empty @monitor.metrics[:executions]
          assert_empty @monitor.metrics[:api_calls]
          assert_empty @monitor.metrics[:tool_calls]
          assert_empty @monitor.metrics[:memory_usage]
        end

        test "monitors execution time" do
          @monitor.start_monitoring
          sleep 0.01 # Small delay to ensure measurable time
          metrics = @monitor.complete_monitoring("result")

          assert metrics[:execution_time] > 0
          assert_equal Time, metrics[:timestamp].class
          assert metrics[:success]
          assert_equal 0, metrics[:api_calls]
          assert_equal 0, metrics[:tool_calls]
        end

        test "records api calls" do
          @monitor.start_monitoring
          @monitor.record_api_call("gpt-4", 150)
          @monitor.record_api_call("gpt-3.5", 100)
          metrics = @monitor.complete_monitoring

          assert_equal 2, metrics[:api_calls]
          assert_equal 2, @monitor.metrics[:api_calls].size
          assert_equal "gpt-4", @monitor.metrics[:api_calls].first[:model]
          assert_equal 150, @monitor.metrics[:api_calls].first[:tokens_used]
        end

        test "records tool calls" do
          @monitor.start_monitoring
          @monitor.record_tool_call("read_file", 0.05)
          @monitor.record_tool_call("grep", 0.1)
          metrics = @monitor.complete_monitoring

          assert_equal 2, metrics[:tool_calls]
          assert_equal 2, @monitor.metrics[:tool_calls].size
          assert_equal "read_file", @monitor.metrics[:tool_calls].first[:tool]
          assert_equal 0.05, @monitor.metrics[:tool_calls].first[:execution_time]
        end

        test "tracks memory usage" do
          @monitor.start_monitoring
          metrics = @monitor.complete_monitoring

          assert_kind_of Integer, metrics[:memory_delta]
          assert_equal 1, @monitor.metrics[:memory_usage].size
        end

        test "generates performance report" do
          # No executions
          assert_equal "No executions recorded", @monitor.generate_report

          # Record some executions
          3.times do |i|
            @monitor.start_monitoring
            @monitor.record_api_call("gpt-4")
            @monitor.record_tool_call("read_file") if i > 0
            sleep 0.01
            @monitor.complete_monitoring("result #{i}")
          end

          report = @monitor.generate_report

          assert_match(/Performance Report/, report)
          assert_match(/Total Executions: 3/, report)
          assert_match(/Execution Time:/, report)
          assert_match(/Average:/, report)
          assert_match(/API Calls:/, report)
          assert_match(/Total: 3/, report)
          assert_match(/Tool Calls:/, report)
          assert_match(/read_file: 2 calls/, report)
        end

        test "checks performance thresholds" do
          @monitor.start_monitoring
          sleep 0.01
          @monitor.record_api_call("gpt-4")
          @monitor.record_tool_call("grep")
          @monitor.complete_monitoring

          # Should pass these thresholds
          assert @monitor.meets_threshold?(
            execution_time: 1.0,
            api_calls: 2,
            tool_calls: 2,
          )

          # Should fail these thresholds
          refute @monitor.meets_threshold?(
            execution_time: 0.001,
            api_calls: 0,
          )
        end

        test "calculates performance trends" do
          # Not enough data
          assert_empty @monitor.performance_trends

          # Record increasing execution times
          [0.01, 0.02, 0.03, 0.04].each do |sleep_time|
            @monitor.start_monitoring
            sleep sleep_time
            @monitor.complete_monitoring
          end

          trends = @monitor.performance_trends
          assert_equal :increasing, trends[:execution_time]
          assert_equal :stable, trends[:api_calls]
        end

        test "formats time correctly" do
          monitor = PerformanceMonitor.new

          # Private method access for testing
          format_time = ->(seconds) { monitor.send(:format_time, seconds) }

          assert_equal "500.0μs", format_time.call(0.0005)
          assert_equal "50.0ms", format_time.call(0.05)
          assert_equal "1.5s", format_time.call(1.5)
        end

        test "formats memory correctly" do
          monitor = PerformanceMonitor.new

          # Private method access for testing
          format_memory = ->(bytes) { monitor.send(:format_memory, bytes) }

          assert_equal "512B", format_memory.call(512)
          assert_equal "2.0KB", format_memory.call(2048)
          assert_equal "1.5MB", format_memory.call(1572864)
        end

        test "calculates result size" do
          monitor = PerformanceMonitor.new

          # Private method access for testing
          result_size = ->(result) { monitor.send(:result_size, result) }

          assert_equal 11, result_size.call("hello world")
          # JSON representation of { key: "value" } is {"key":"value"} which is 15 chars
          assert_equal 15, result_size.call({ key: "value" })
          assert_equal 11, result_size.call([1, 2, 3, 4, 5])
        end

        test "handles multiple monitoring sessions" do
          # First session
          @monitor.start_monitoring
          @monitor.record_api_call("gpt-4")
          @monitor.complete_monitoring("result1")

          # Second session
          @monitor.start_monitoring
          @monitor.record_api_call("gpt-3.5")
          @monitor.record_tool_call("grep")
          @monitor.complete_monitoring("result2")

          assert_equal 2, @monitor.metrics[:executions].size
          assert_equal 2, @monitor.metrics[:api_calls].size
          assert_equal 1, @monitor.metrics[:tool_calls].size
        end
      end
    end
  end
end
