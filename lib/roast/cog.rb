# typed: true
# frozen_string_literal: true

module Roast
  class Cog
    class CogError < Roast::Error; end

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
      @output = nil #: Cog::Output?
      @skipped = false #: bool
      @failed = false #: bool

      # Make sure a config is always defined, so we don't have to worry about nils
      @config = self.class.config_class.new #: untyped
    end

    #: (Async::Barrier, Cog::Config, CogInputContext, untyped, Integer) -> Async::Task
    def run!(barrier, config, input_context, executor_scope_value, executor_scope_index)
      raise CogAlreadyStartedError if @task

      @task = barrier.async(finished: false) do |task|
        task.annotate("#{self.class.name.!.demodulize.camelcase} Cog: #{@name}")
        @config = config
        input_instance = self.class.input_class.new
        input_return = input_context.instance_exec(
          input_instance, executor_scope_value, executor_scope_index, &@cog_input_proc
        ) if @cog_input_proc
        coerce_and_validate_input!(input_instance, input_return)
        @output = execute(input_instance)
      rescue ControlFlow::SkipCog
        # TODO: do something with the message passed to skip!
        @skipped = true
      rescue ControlFlow::FailCog => e
        # TODO: do something with the message passed to fail!
        @failed = true
        # TODO: better / cleaner handling in the workflow execution manager for a workflow failure
        #   just re-raising this exception for now
        raise e if config.abort_on_failure?
      rescue ControlFlow::Next, ControlFlow::Break => e
        @skipped = true
        raise e
      rescue StandardError => e
        @failed = true
        raise e
      end
    end

    #: () -> void
    def wait
      @task&.wait
    rescue
      # Do nothing if the cog's task raised an exception. That is handled elsewhere.
    end

    #: () -> bool
    def started?
      @task.present?
    end

    #: () -> bool
    def skipped?
      @skipped
    end

    #: () -> bool
    def failed?
      @failed || !!@task&.failed?
    end

    #: () -> bool
    def stopped?
      !!@task&.stopped?
    end

    #: () -> bool
    def succeeded?
      # NOTE: explicitly checking `@output == nil` because the `ruby` cog's Output class delegates
      # all missing methods to its `value`, which may be nil when the Output object is actually present.
      @output != nil && @task&.finished? # rubocop:disable Style/NonNilCheck
    end

    protected

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
