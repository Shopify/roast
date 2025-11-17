# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class ConsoleInterface
      class Item
        #: String
        attr_reader :message

        #: bool
        attr_reader :error

        #: (String, bool) -> void
        def initialize(message, error)
          @message = message
          @error = error
        end
      end

      #: (bool) -> void
      def initialize(verbose)
        @verbose = verbose
        @queue = Async::Queue.new #: Async::Queue
      end

      #: () -> Async::Task
      def start!
        @task = Async(transient: true) do
          ::CLI::UI::FiberSupport.enable!
          ::CLI::UI::StdoutRouter.enable
          ::CLI::UI::Frame.open("Outer") do
            loop do
              item = @queue.pop #: as Item?
              break if item.nil?

              puts "#{item.error ? "ERROR" : "OUTPUT"}: #{item.message}"
            end
          end
        end
      end

      #: () -> void
      def stop!
        @queue.close
        @task&.wait
      end

      #: (String?, ?bool) -> void
      def put(message, error = false)
        @queue.push(Item.new(message, error)) unless message.nil?
      end

      alias_method(:<<, :put)
    end
  end
end
