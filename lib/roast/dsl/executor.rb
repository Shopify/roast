# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    class Executor
      class << self
        #: (?String?) -> void
        def call(file_path = nil)
          new(file_path).call
        end
      end

      attr_reader :file_path

      #: (?String?) -> void
      def initialize(file_path = nil)
        @file_path = file_path
        @execute_blocks = []
      end

      #: () -> void
      def call
        if dsl_file_path.nil?
          Roast::Helpers::Logger.error(<<~NO_FILE)
            No roast DSL file found in current directory
          NO_FILE

          exit(1)
        end

        execute_file
      end

      #: () -> String
      def dsl_file_path
        @dsl_file_path ||= begin
          fpath = File.expand_path(@file_path)
          unless File.exist?(fpath)
            raise Roast::Error, "DSL file not found: #{fpath}"
          end

          fpath
        end
      end

      #: () -> void
      def execute_file
        setup_execute_method

        load(dsl_file_path)

        # Execute any captured execute blocks
        execute_captured_blocks
      rescue => e
        Roast::Helpers::Logger.error(<<~ERROR)
          #{e.class.name}: #{e.message}
          Backtrace:
          #{e.backtrace&.join("\n")}
        ERROR

        exit(1)
      end

      #: (Proc) -> void
      def capture_execute_block(block)
        @execute_blocks << block
      end

      private

      #: () -> void
      def setup_execute_method
        TOPLEVEL_BINDING.eval(<<~RUBY)
          def execute(&block)
            ObjectSpace._id2ref(#{object_id}).capture_execute_block(block)
          end
        RUBY
      end

      #: () -> void
      def execute_captured_blocks
        @execute_blocks.each do |block|
          # Load cogs into a new binding scope
          execute_binding = create_execute_binding

          # Execute the block in the binding with cogs available
          execute_binding.instance_eval(&block)
        end
      end

      #: () -> Object
      def create_execute_binding
        # Create a new object to serve as the execution context
        execute_context = Object.new

        # Load cogs and bind them to the execution context
        Roast::DSL::Cogs.load_all_for(dsl_file_path)

        # Define cog methods on the execution context
        Roast::DSL::Cogs.all_cog_classes.each do |cog_class|
          method_name = T.cast(cog_class, T.class_of(Roast::DSL::Cog)).method_name
          execute_context.define_singleton_method(method_name) do |*args, **kwargs, &block|
            T.cast(cog_class, T.class_of(Roast::DSL::Cog)).invoke(*args, **kwargs, &block)
          end
        end

        execute_context
      end
    end
  end
end
