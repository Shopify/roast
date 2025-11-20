# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    # Context in which an individual cog block within the `execute` block of a workflow is evaluated
    class CogInputManager
      class CogOutputAccessError < Roast::Error; end

      class CogDoesNotExistError < CogOutputAccessError; end

      class CogNotYetRunError < CogOutputAccessError; end

      class CogSkippedError < CogOutputAccessError; end

      class CogFailedError < CogOutputAccessError; end

      class CogStoppedError < CogOutputAccessError; end

      #: (Cog::Registry, Cog::Store, WorkflowContext) -> void
      def initialize(cog_registry, cogs, workflow_context)
        @cog_registry = cog_registry
        @cogs = cogs
        @workflow_context = workflow_context
        @context = CogInputContext.new
        bind_registered_cogs
        bind_workflow_context
      end

      #: CogInputContext
      attr_reader :context

      private

      #: () -> void
      def bind_registered_cogs
        @cog_registry.cogs.keys.each(&method(:bind_cog))
      end

      #: (Symbol) -> void
      def bind_cog(cog_method_name)
        cog_question_method_name = (cog_method_name.to_s + "?").to_sym
        cog_bang_method_name = (cog_method_name.to_s + "!").to_sym
        cog_output_method = method(:cog_output)
        cog_output_question_method = method(:cog_output?)
        cog_output_bang_method = method(:cog_output!)
        @context.instance_eval do
          define_singleton_method(cog_method_name, proc { |cog_name| cog_output_method.call(cog_name) })
          define_singleton_method(cog_question_method_name, proc { |cog_name| cog_output_question_method.call(cog_name) })
          define_singleton_method(cog_bang_method_name, proc { |cog_name| cog_output_bang_method.call(cog_name) })
        end
      end

      #: (Symbol) -> Cog::Output?
      def cog_output(cog_name)
        cog_output!(cog_name)
      rescue CogOutputAccessError => e
        # Even this method should raise an exception if the requested cog does not exist at all
        raise e if e.is_a?(CogDoesNotExistError)

        nil
      end

      #: (Symbol) -> bool
      def cog_output?(cog_name)
        !cog_output(cog_name).nil?
      end

      #: (Symbol) -> Cog::Output
      def cog_output!(cog_name)
        raise CogDoesNotExistError, cog_name unless @cogs.key?(cog_name)

        @cogs[cog_name].tap do |cog|
          cog.wait # attempting to access the output of a running cog will block until that cog completes
          raise CogSkippedError, cog_name if cog.skipped?
          raise CogFailedError, cog_name if cog.failed?
          raise CogStoppedError, cog_name if cog.stopped?
          raise CogNotYetRunError, cog_name unless cog.succeeded?
        end.output.deep_dup
      end

      #: () -> void
      def bind_workflow_context
        target_bang_method = method(:target!)
        targets_method = method(:targets)
        arg_question_method = method(:arg?)
        args_method = method(:args)
        kwarg_method = method(:kwarg)
        kwarg_bang_method = method(:kwarg!)
        kwarg_question_method = method(:kwarg?)
        kwargs_method = method(:kwargs)
        tmpdir_method = method(:tmpdir)
        @context.instance_eval do
          define_singleton_method(:target!, proc { target_bang_method.call })
          define_singleton_method(:targets, proc { targets_method.call })
          define_singleton_method(:arg?, proc { |value| arg_question_method.call(value) })
          define_singleton_method(:args, proc { args_method.call })
          define_singleton_method(:kwarg, proc { |key| kwarg_method.call(key) })
          define_singleton_method(:kwarg!, proc { |key| kwarg_bang_method.call(key) })
          define_singleton_method(:kwarg?, proc { |key| kwarg_question_method.call(key) })
          define_singleton_method(:kwargs, proc { kwargs_method.call })
          define_singleton_method(:tmpdir, proc { tmpdir_method.call })
        end
      end

      #: () -> String
      def target!
        raise ArgumentError, "expected exactly one target" unless @workflow_context.params.targets.length == 1

        @workflow_context.params.targets.first #: as String
      end

      #: () -> Array[String]
      def targets
        @workflow_context.params.targets.dup
      end

      #: (Symbol) -> bool
      def arg?(value)
        @workflow_context.params.args.include?(value)
      end

      #: () -> Array[Symbol]
      def args
        @workflow_context.params.args.dup
      end

      #: (Symbol) -> String?
      def kwarg(key)
        @workflow_context.params.kwargs[key]
      end

      #: (Symbol) -> String
      def kwarg!(key)
        raise ArgumentError, "expected keyword argument '#{key}' to be present" unless @workflow_context.params.kwargs.include?(key)

        @workflow_context.params.kwargs[key] #: as String
      end

      #: (Symbol) -> bool
      def kwarg?(key)
        @workflow_context.params.kwargs.include?(key)
      end

      #: () -> Hash[Symbol, String]
      def kwargs
        @workflow_context.params.kwargs.dup
      end

      #: () -> Pathname
      def tmpdir
        Pathname.new(@workflow_context.tmpdir).realpath
      end
    end
  end
end
