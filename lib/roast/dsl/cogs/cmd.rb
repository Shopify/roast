# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
        # TODO: User-facing doc comment about the cog's configuration options would ideally go here,
        #   and then get copied to config_context.rbi by the tapioca compiler.
        #   For now, just writing the doc comments there to avoid duplication
        class Config < Cog::Config
          # Configure the cog to write both STDOUT and STDERR to the console
          #
          # - Alias: `print_all!`
          # - Alias: `display!`
          #
          #: () -> void
          def print_all!
            # comment about how this method works
            @values[:print_stdout] = true
            @values[:print_stderr] = true
          end

          # Configure the cog to write __no output__ to the console, neither STDOUT nor STDERR
          #
          # - Alias: `no_print_all!`
          # - Alias: `no_display!`
          #
          #: () -> void
          def print_none!
            @values[:print_stdout] = false
            @values[:print_stderr] = false
          end

          # Configure the cog to write STDOUT to the console
          #
          # Disabled by default
          #
          #: () -> void
          def print_stdout!
            @values[:print_stdout] = true
          end

          # Configure the cog __not__ to write STDOUT to the console
          #
          #: () -> void
          def no_print_stdout!
            @values[:print_stdout] = false
          end

          # Configure the cog to write STDERR to the console
          #
          # Disabled by default
          #
          #: () -> void
          def print_stderr!
            @values[:print_stderr] = true
          end

          # Configure the cog __not__ to write STDERR to the console
          #
          #: () -> void
          def no_print_stderr!
            @values[:print_stderr] = false
          end

          # Configure the cog to strip surrounding whitespace from the values in its output object
          #
          # Default: `true`
          #
          #: () -> void
          def clean_output!
            @values[:raw_output] = false
          end

          # Configure the cog __not__ to strip surrounding whitespace from the values in its output object
          #
          # Default: `false`
          #
          #: () -> void
          def raw_output!
            @values[:raw_output] = true
          end

          # Check if the cog is configured to write STDOUT to the console
          #
          #: () -> bool
          def print_stdout?
            !!@values[:print_stdout]
          end

          # Check if the cog is configured to write STDERR to the console
          #
          #: () -> bool
          def print_stderr?
            !!@values[:print_stderr]
          end

          # Check if the cog is configured to write its output to the console in raw form
          #
          #: () -> bool
          def raw_output?
            !!@values[:raw_output]
          end

          alias_method(:display!, :print_all!)
          alias_method(:no_display!, :print_none!)
        end

        class Input < Cog::Input
          #: String?
          attr_accessor :command

          #: Array[String]
          attr_accessor :args

          #: () -> void
          def initialize
            super
            @args = []
          end

          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'command' is required" unless command.present?
          end

          #: (String | Array[untyped]) -> void
          def coerce(input_return_value)
            case input_return_value
            when String
              self.command = input_return_value
            when Array
              input_return_value.map!(&:to_s)
              self.command = input_return_value.shift
              self.args = input_return_value
            end
          end
        end

        class Output < Cog::Output
          #: String
          attr_reader :out

          #: String
          attr_reader :err

          #: Process::Status
          attr_reader :status

          #: ( String, String, Process::Status) -> void
          def initialize(out, err, status)
            super()
            @out = out #: String
            @err = err #: String
            @status = status #: Process::Status
          end
        end

        #: (Input) -> Output
        def execute(input)
          config = @config #: as Config

          stdout_handler = config.print_stdout? ? ->(line) { $stdout.print(line) } : nil
          stderr_handler = config.print_stderr? ? ->(line) { $stderr.print(line) } : nil

          stdout, stderr, status = CommandRunner #: as untyped
            .execute(
              [input.command] + input.args,
              stdout_handler: stdout_handler,
              stderr_handler: stderr_handler,
            )

          unless config.raw_output?
            stdout = stdout.strip
            stderr = stderr.strip
          end

          Output.new(stdout, stderr, status)
        end
      end
    end
  end
end
