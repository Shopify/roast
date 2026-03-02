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
      # The first path element is always the top-level ExecutionManager
      handle_begin_workflow_event(event) if event.path.length == 1
      return unless event[:begin].cog.present?

      Roast::Log.logger.info { "#{format_path(event)} Starting" }
    end

    def handle_begin_workflow_event(event)
      execution_manager = event[:begin].execution_manager.not_nil!
      workflow_context = execution_manager.workflow_context
      Roast::Log.logger.info("🔥🔥🔥 Workflow Starting")
      Roast::Log.logger.debug do
        message = <<~MESSAGE
          Workflow Context:
            Targets: #{workflow_context.params.targets}
            Args: #{workflow_context.params.args}
            Kwargs: #{workflow_context.params.kwargs}
            Temporary Directory: #{workflow_context.tmpdir}
            Workflow Directory: #{workflow_context.workflow_dir}
            Working Directory: #{Dir.pwd}
        MESSAGE
        message.strip
      end
    end

    #: (Event) -> void
    def handle_end_event(event)
      # The first path element is always the top-level ExecutionManager
      Roast::Log.logger.info("🔥🔥🔥 Workflow Complete") if event.path.length == 1
      return unless event[:end].cog.present?

      Roast::Log.logger.info { "#{format_path(event)} Complete" }
    end

    #: (Event) -> void
    def handle_log_event(event)
      Roast::Log.logger.add(event.log_severity, "#{format_path(event)} #{event.log_message}")
    end

    #: (Event) -> void
    def handle_stderr_event(event)
      Roast::Log.logger.warn { "#{format_path(event)} ❯❯ #{event[:stderr]}" }
    end

    #: (Event) -> void
    def handle_stdout_event(event)
      Roast::Log.logger.info { "#{format_path(event)} ❯ #{event[:stdout]}" }
    end

    #: (Event) -> void
    def handle_unknown_event(event)
      Roast::Log.logger.unknown(event.inspect)
    end

    #: (Event) -> String
    def format_path(event)
      event.path.map do |element|
        cog = element.cog
        execution_manager = element.execution_manager
        if cog.present?
          "#{cog.type}#{cog.anonymous? ? "" : "(:#{cog.name})"}"
        elsif execution_manager&.scope
          "{:#{execution_manager.scope}}[#{execution_manager.scope_index}]"
        end
      end.compact.join(" -> ")
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
