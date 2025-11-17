# frozen_string_literal: true

require "test_helper"

module Roast
  module DSL
    class WorkflowTest < ActiveSupport::TestCase
      test "from_file raises error when file does not exist" do
        assert_raises(Errno::ENOENT) do
          Workflow.from_file("/non/existent/file.rb", WorkflowParams.new([], [], {}))
        end
      end

      test "foo1" do
        Sync do |task|
          task.annotate "Main task"
          tasks = []
          tasks << task.async do |task|
            task.annotate "Task One"
            sleep 0.2
            puts "mid 1"
            sleep 0.2
            puts "done 1"
          end
          tasks << Async do |task|
            task.annotate "Task Two"
            raise StandardError, "crash"
            # sleep 0.4
            # puts "done 2"
          end
          sleep 0.3
          task.print_hierarchy($stdout)
          tasks.each(&:wait)
        end
        assert true
      end

      test "foo2" do
        Async do
          sem = Async::Semaphore.new(2)
          sem.async do
            puts "hi"
            sleep 0.4
            puts "hi2"
          end
          sem.async do
            puts "by"
          end
        end
      end

      test "foo3" do
        queue = Async::Queue.new
        barrier = Async::Barrier.new
        Sync do
          barrier.async do
            loop do
              message = queue.pop
              break if message.nil?
              puts message
            end
          end
          barrier.async do
            3.times do |it|
              queue.push it
              sleep 0.25
              queue.push nil
            end
            queue.close
          end
          barrier.wait
          puts "done"
        end
      end
    end
  end
end
