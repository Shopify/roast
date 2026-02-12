# typed: true
# frozen_string_literal: true

module Roast
  class OutputRouter
    # This is the name of the alias methods for `:write` on the $stdout and $stderr objects
    # that bypass OutputRouter's wrapper. Calling this method will write to those output stream directly.
    WRITE_WITHOUT_ROAST = :write_without_roast

    class << self
      #: () -> bool
      def enable!
        return false if enabled?

        activate($stdout, :stdout)
        activate($stderr, :stderr)
        mark_as_output_fiber!
        true
      end

      #: () -> bool
      def disable!
        return false unless enabled?

        deactivate($stdout)
        deactivate($stderr)
        @output_fiber = nil
        true
      end

      #: () -> bool
      def enabled?
        $stdout.respond_to?(WRITE_WITHOUT_ROAST)
      end

      #: () -> bool
      def output_fiber?
        @output_fiber == Fiber.current
      end

      #: () -> void
      def mark_as_output_fiber!
        @output_fiber = Fiber.current
      end

      private

      #: (IO stream, Symbol name) -> void
      def activate(stream, name)
        router = self
        stream.singleton_class.send(:alias_method, WRITE_WITHOUT_ROAST, :write)
        stream.define_singleton_method(:write) do |*args|
          if router.output_fiber?
            self #: as untyped # rubocop:disable Style/RedundantSelf
              .send(WRITE_WITHOUT_ROAST, *args)
          else
            str = args.map(&:to_s).join
            Event << case name
            when :stdout then { stdout: str }
            when :stderr then { stderr: str }
            else { unknown: str }
            end
          end
        end
      end

      #: (IO stream) -> void
      def deactivate(stream)
        sc = stream.singleton_class
        sc.send(:remove_method, :write)
        sc.send(:alias_method, :write, WRITE_WITHOUT_ROAST)
        sc.send(:remove_method, WRITE_WITHOUT_ROAST)
      end
    end
  end
end
