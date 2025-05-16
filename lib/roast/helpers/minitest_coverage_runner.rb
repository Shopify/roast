# frozen_string_literal: true

require "coverage"
require "minitest"
require_relative "logger"

module Roast
  module Helpers
    class TestStatsCollector
      attr_reader :tests_count, :assertions_count

      def initialize
        @tests_count = 0
        @assertions_count = 0

        # Install our hook into Minitest's before and after hooks
        Minitest.after_run { @reported = true }

        # Install a custom hook to count tests
        Minitest::Test.class_eval do
          original_run = instance_method(:run)

          define_method(:run) do |*args|
            result = original_run.bind(self).call(*args)
            TestStatsCollector.instance.count_test(result)
            result
          end
        end
      end

      def count_test(result)
        @tests_count += 1
        @assertions_count += result.assertions
      end

      class << self
        def instance
          @instance ||= new
        end
      end
    end

    class MinitestCoverageRunner
      def initialize(test_file_path, subject_file_path)
        @test_file = File.expand_path(test_file_path)
        @subject_file = File.expand_path(subject_file_path)

        # Detect Rails vs Gem by checking for config/environment.rb or a .gemspec
        @rails_app   = File.exist?(File.join(Dir.pwd, "config", "environment.rb"))
        @gem_project = Dir.glob(File.join(Dir.pwd, "*.gemspec")).any?
      end

      def run
        # Make sure the test dir (and possibly the test file's dir) is on the LOAD_PATH,
        # so that 'require "test_helper"' from inside the test works in plain IRB.
        ensure_load_path_for_test

        # Start coverage
        Coverage.start(lines: true, branches: true, methods: true)

        # If Rails app, load Rails environment & test_help
        if @rails_app
          ENV["RAILS_ENV"]      = "test"
          ENV["DISABLE_SPRING"] = "1" # ensure we don't use Spring, so coverage is captured
          require File.expand_path("config/environment", Dir.pwd)
          require "rails/test_help"
        else
          require "bundler/setup"
        end

        # Now require the test file directly
        require @test_file

        # Require the source file to make sure it's loaded for coverage
        require @subject_file

        # Initialize our test stats collector - must happen before tests run
        stats_collector = TestStatsCollector.instance

        # Run Minitest tests
        # Redirect stdout to stderr for test output so that it doesn't pollute
        # the JSON output of the coverage runner
        original_stdout = $stdout.dup
        $stdout.reopen($stderr)
        test_passed = Minitest.run([])
        $stdout.reopen(original_stdout) # Restore original stdout

        # Report test stats
        test_count = stats_collector.tests_count
        assertion_count = stats_collector.assertions_count

        coverage_data = Coverage.result(stop: false)

        file_data = coverage_data[@subject_file]
        coverage_result =
          if file_data.nil?
            # If file never got loaded, coverage is effectively zero for that file
            { line: 0.0, branch: 0.0, method: 0.0, tests: test_count, assertions: assertion_count }
          else
            result = compute_coverage_stats(file_data)
            result.merge(tests: test_count, assertions: assertion_count)
          end

        # If the test run failed (returned false), exit 1
        unless test_passed
          Roast::Helpers::Logger.error("\nTest failures detected. Exiting with status 1.")
          exit(1)
        end

        puts coverage_result.to_json
      end

      private

      # Ensures that your test directory (and possibly the directory of the test file)
      # is added to the load path so `require 'test_helper'` works from IRB context.
      def ensure_load_path_for_test
        test_dir = File.join(Dir.pwd, "test")
        $LOAD_PATH.unshift(test_dir) if File.directory?(test_dir) && !$LOAD_PATH.include?(test_dir)

        # Also add the directory of the specific test file; sometimes test files are in subdirs like `test/models`
        test_file_dir = File.dirname(@test_file)
        unless $LOAD_PATH.include?(test_file_dir)
          $LOAD_PATH.unshift(test_file_dir)
        end
      end

      def compute_coverage_stats(file_data)
        lines_info    = file_data[:lines]    || []
        branches_info = file_data[:branches] || {}
        methods_info  = file_data[:methods]  || {}
        source_code_lines = File.readlines(@subject_file).map(&:chomp)

        # --- Line Coverage ---
        executable_lines = lines_info.count { |count| !count.nil? }
        covered_lines    = lines_info.count { |count| count && count > 0 }
        line_percent = if executable_lines.zero?
          100.0
        else
          (covered_lines.to_f / executable_lines * 100).round(2)
        end

        # --- Branch Coverage ---
        total_branches   = 0
        covered_branches = 0
        uncovered_branches = []

        # Track line numbers with branches for reporting
        branches_info.each do |line_number, branch_group|
          # Convert line_number from symbol/array to integer if needed
          # Ruby Coverage module can return different formats for line numbers
          line_num = if line_number.is_a?(Array)
            line_number[2] # Usually the line number is the 3rd element in the array
          elsif line_number.is_a?(Symbol)
            # Try to extract line number from a symbol like :line_10
            begin
              line_number.to_s.match(/\d+/)&.[](0).to_i
            rescue
              0
            end
          else
            line_number.to_i
          end

          # Adjust for zero-based line numbering if needed
          actual_line_num = [line_num, 0].max

          # Get the actual code from that line if available
          line_code = begin
            source_code_lines[actual_line_num - 1]&.strip
          rescue
            "Unknown code"
          end

          branch_group.each do |_branch_id, count|
            total_branches += 1
            if count && count > 0
              covered_branches += 1
            else
              # Add uncovered branch to the result with line number and code
              uncovered_branches << "Line #{actual_line_num}: #{line_code}"
            end
          end
        end

        branch_percent = if total_branches.zero?
          100.0
        else
          (covered_branches.to_f / total_branches * 100).round(2)
        end

        # --- Method Coverage ---
        total_methods   = methods_info.size
        covered_methods = 0
        uncovered_methods = []

        methods_info.each do |method_id, count|
          # Method IDs in Coverage are usually in the format: [class_name, method_name, start_line, end_line]
          if method_id.is_a?(Array) && method_id.size >= 4
            class_name, method_name, start_line, end_line = method_id
            # Construct a user-friendly representation of the method
            method_signature = "#{class_name}##{method_name} (lines #{start_line}-#{end_line})"

            if count && count > 0
              covered_methods += 1
            else
              # Add uncovered method to the result
              uncovered_methods << method_signature
            end
          elsif count && count > 0
            # Handle any other format the Coverage module might return
            covered_methods += 1
          else
            uncovered_methods << method_id.to_s
          end
        end

        method_percent = if total_methods.zero?
          100.0
        else
          (covered_methods.to_f / total_methods * 100).round(2)
        end

        {
          line: line_percent,
          branch: branch_percent,
          method: method_percent,
          uncovered_branches: uncovered_branches,
          uncovered_methods: uncovered_methods,
        }
      end
    end
  end
end
