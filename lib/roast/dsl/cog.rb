# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Cog
      class CogError < Roast::Error; end

      class CogAlreadyRanError < CogError; end

      class CogAlreadyStartedError < CogError; end

      class << self
        #: () -> singleton(Cog::Config)
        def config_class
          @config_class ||= find_child_config_or_default
        end

        #: () -> singleton(Cog::Input)
        def input_class
          @input_class ||= find_child_input_or_default #: singleton(Cog::Input)?
        end

        #: () -> Symbol
        def generate_fallback_name
          Random.uuid.to_sym
        end

        private

        #: () -> singleton(Cog::Config)
        def find_child_config_or_default
          config_constant = "#{name}::Config"
          const_defined?(config_constant) ? const_get(config_constant) : Cog::Config # rubocop:disable Sorbet/ConstantsFromStrings
        end

        #: () -> singleton(Cog::Input)
        def find_child_input_or_default
          input_constant = "#{name}::Input"
          const_defined?(input_constant) ? const_get(input_constant) : Cog::Input # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end

      #: Symbol
      attr_reader :name

      #: Cog::Output?
      attr_reader :output

      #: (Symbol, ^(Cog::Input) -> untyped) -> void
      def initialize(name, cog_input_proc)
        @name = name
        @cog_input_proc = cog_input_proc #: ^(Cog::Input) -> untyped
        @run_semaphore = Async::Semaphore.new(1) #: Async::Semaphore
        @started = false #: bool
        @output = nil #: Cog::Output?
        @skipped = false #: bool
        @failed = false #: bool

        # Make sure a config is always defined, so we don't have to worry about nils
        @config = self.class.config_class.new #: untyped
      end

      #: (Cog::Config, CogInputContext, untyped, Integer) -> Async::Task
      def run!(config, input_context, executor_scope_value, executor_scope_index)
        @run_semaphore.async do # prevents multiple invocations of run! from occurring in parallel
          raise CogAlreadyRanError if @output.present? || @skipped || @failed
          raise CogAlreadyStartedError if @started

          @started = true
          @config = config
          input_instance = self.class.input_class.new
          input_return = input_context.instance_exec(
            input_instance, executor_scope_value, executor_scope_index, &@cog_input_proc
          ) if @cog_input_proc
          coerce_and_validate_input!(input_instance, input_return)
          @output = execute(input_instance)
        rescue ControlFlow::SkipCog
          @skipped = true
        rescue ControlFlow::FailCog => e
          @failed = true
          # TODO: better / cleaner handling in the workflow execution manager for a workflow failure
          #   just re-raising this exception for now
          raise e if config.abort_on_error?
        rescue Input::InvalidInputError => e
          @failed = true
          # Format input validation errors in a user-friendly way
          error_formatter = ErrorFormatter.new
          error_formatter.print_error(e, step_name: @name.to_s)
          raise e if config.abort_on_error?
        rescue => e
          @failed = true
          # Format unexpected cog errors
          error_formatter = ErrorFormatter.new
          error_formatter.print_error(e, step_name: @name.to_s)
          raise e if config.abort_on_error?
        end
      end

      #: () -> bool
      def started?
        # NOTE: explicitly not waiting for the cog's task to complete before answering, as in the other methods below,
        # because this method is intended to be potentially called while the cog is running.
        @started
      end

      #: () -> bool
      def ran?
        # NOTE: this will block until the cog finished running IF it is currently running
        # It will answer immediately if the cog has not started to run
        answer = @run_semaphore.async do
          @output.present? || @skipped || @failed
        end.wait
        # NOTE: this answer will be `nil` if this block that is simply checking for the output/result is stopped,
        # not if the cog's task itself was stopped. This should really never happen.
        raise CogError, "task stopped while fetching value" if answer.nil?

        answer
      end

      #: () -> bool
      def skipped?
        # see NOTEs on `ran?`
        answer = @run_semaphore.async do
          @skipped
        end.wait
        raise CogError, "task stopped while fetching value" if answer.nil?

        answer
      end

      #: () -> bool
      def failed?
        # see NOTEs on `ran?`
        answer = @run_semaphore.async do
          @failed
        end.wait
        raise CogError, "task stopped while fetching value" if answer.nil?

        answer
      end

      #: () -> bool
      def stopped?
        # see NOTEs on `ran?`
        answer = @run_semaphore.async do
          @started && !@output.present? && !@skipped && !@failed
        end.wait
        raise CogError, "task stopped while fetching value" if answer.nil?

        answer
      end

      # Inheriting cog must implement this
      #: (Cog::Input) -> Cog::Output
      def execute(input)
        raise NotImplementedError
      end

      private

      #: (Cog::Input, untyped) -> void
      def coerce_and_validate_input!(input, return_value)
        # Check if the input is already valid
        input.validate!
      rescue Cog::Input::InvalidInputError
        # If it's not valid, attempt to coerce if possible
        input.coerce(return_value)
        # Re-validate because coerce! should not be responsible for validation
        input.validate!
      end
    end
  end
end
