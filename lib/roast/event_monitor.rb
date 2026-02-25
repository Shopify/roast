# typed: true
# frozen_string_literal: true

module Roast
  module EventMonitor
    extend self
    include Kernel

    class EventMonitorError < StandardError; end

    class EventMonitorAlreadyStartedError < EventMonitorError; end

    class EventMonitorNotRunningError < EventMonitorError; end

    @queue = Async::Queue.new.tap(&:close) #: Async::Queue
    @task = nil #: Async::Task?

    #: () -> bool
    def running?
      !@queue.closed?
    end

    #: () -> Async::Task
    def start!
      raise EventMonitorAlreadyStartedError if running?

      OutputRouter.enable!
      @queue = Async::Queue.new
      @task = Async(transient: true) do
        OutputRouter.mark_as_output_fiber!
        loop do
          event = @queue.pop #: as Event?
          break if event.nil?

          handle_event(event)
        end
      end
    end

    #: () -> void
    def stop!
      raise EventMonitorNotRunningError unless running?

      OutputRouter.disable!
      @queue.close
      @task&.wait
      @task = nil
    end

    #: () -> void
    def reset!
      OutputRouter.disable!
      @queue.close
      @task = nil
    end

    #: (Event) -> void
    def accept(event)
      if running?
        @queue.push(event)
      else
        handle_event(event)
      end
    end

    private

    #: (Event) -> void
    def handle_event(event)
      with_stubbed_class_method_returning(Time, :now, event.time) do
        OutputRouter.mark_as_output_fiber!
        handler_method_name = "handle_#{event.type}_event".to_sym
        if respond_to?(handler_method_name, true)
          send(handler_method_name, event)
        else
          handle_unknown_event(event)
        end
      end
    end

    #: (Event) -> void
    def handle_begin_event(event)
      Roast::Log.logger.debug(event.inspect)
    end

    #: (Event) -> void
    def handle_end_event(event)
      Roast::Log.logger.debug(event.inspect)
    end

    #: (Event) -> void
    def handle_log_event(event)
      Roast::Log.logger.add(event.log_severity, event.log_message)
    end

    #: (Event) -> void
    def handle_stderr_event(event)
      puts event[:stderr]
    end

    #: (Event) -> void
    def handle_stdout_event(event)
      puts event[:stdout]
    end

    #: (Event) -> void
    def handle_unknown_event(event)
      Roast::Log.logger.unknown(event.inspect)
    end

    #: [T] (Class, Symbol, untyped) { () -> T } -> T
    def with_stubbed_class_method_returning(klass, method_name, return_value, &blk)
      original_method = klass.singleton_class.instance_method(method_name)
      klass.singleton_class.silence_redefinition_of_method(method_name)
      klass.define_singleton_method(method_name, proc { return_value })
      blk.call
    ensure
      if original_method
        klass.singleton_class.silence_redefinition_of_method(method_name)
        klass.define_singleton_method(method_name, original_method)
      end
    end
  end
end
