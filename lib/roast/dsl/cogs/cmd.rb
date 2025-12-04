# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
        # Configure the `cmd` cog
        #
        # See sorbet/rbi/shims/lib/roast/dsl/config_context.rbi for full class documentation.
        class Config < Cog::Config
          # Configure the cog to consider itself failed if the command returns a non-zero exit status
          #
          # Enabled by default. When enabled, a non-zero exit status will mark the cog as failed,
          # which may also abort the workflow depending on the cog's `abort_on_failure` configuration.
          #
          # #### Inverse Methods
          # - `no_fail_on_error!`
          #
          # #### See Also
          # - `fail_on_error?`
          # - `abort_on_failure!`
          #
          #: () -> void
          def fail_on_error!
            @values[:fail_on_error] = true
          end

          # Configure the cog __not__ to consider itself failed if the command returns a non-zero exit status
          #
          # When disabled, the cog will complete successfully regardless of the command's exit status.
          # The exit status will still be available in the output for inspection.
          #
          # #### Inverse Methods
          # - `fail_on_error!`
          #
          # #### See Also
          # - `fail_on_error?`
          #
          #: () -> void
          def no_fail_on_error!
            @values[:fail_on_error] = false
          end

          # Check if the cog is configured to fail when the command returns a non-zero exit status
          #
          # #### See Also
          # - `fail_on_error!`
          # - `no_fail_on_error!`
          #
          #: () -> bool
          def fail_on_error?
            @values[:fail_on_error] != false
          end

          # Configure the cog to write STDOUT to the console
          #
          # Disabled by default.
          #
          # #### See Also
          # - `no_show_stdout!`
          # - `show_stdout?`
          # - `display!`
          #
          #: () -> void
          def show_stdout!
            raise "⚠️ DEPRECATION: use #{__callee__.to_s.sub("print_", "show_")} instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stdout] = true
          end

          # Configure the cog __not__ to write STDOUT to the console
          #
          # #### See Also
          # - `show_stdout!`
          # - `show_stdout?`
          # - `no_display!`
          #
          #: () -> void
          def no_show_stdout!
            raise "⚠️ DEPRECATION: use #{__callee__.to_s.sub("print_", "show_")} instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stdout] = false
          end

          # Check if the cog is configured to write STDOUT to the console
          #
          # #### See Also
          # - `show_stdout!`
          # - `no_show_stdout!`
          #
          #: () -> bool
          def show_stdout?
            !!@values[:show_stdout]
          end

          # Configure the cog to write STDERR to the console
          #
          # Disabled by default.
          #
          # #### See Also
          # - `no_show_stderr!`
          # - `show_stderr?`
          # - `display!`
          #
          #: () -> void
          def show_stderr!
            raise "⚠️ DEPRECATION: use #{__callee__.to_s.sub("print_", "show_")} instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stderr] = true
          end

          # Configure the cog __not__ to write STDERR to the console
          #
          # #### See Also
          # - `show_stderr!`
          # - `show_stderr?`
          # - `no_display!`
          #
          #: () -> void
          def no_show_stderr!
            raise "⚠️ DEPRECATION: use #{__callee__.to_s.sub("print_", "show_")} instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stderr] = false
          end

          # Check if the cog is configured to write STDERR to the console
          #
          # #### See Also
          # - `show_stderr!`
          # - `no_show_stderr!`
          #
          #: () -> bool
          def show_stderr?
            !!@values[:show_stderr]
          end

          # Configure the cog to write both STDOUT and STDERR to the console
          #
          # #### Alias Methods
          # - `display!`
          # - `print_all!`
          #
          # #### See Also
          # - `no_display!`
          # - `show_stdout!`
          # - `show_stderr!`
          #
          #: () -> void
          def display!
            raise "⚠️ DEPRECATION: use display! instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stdout] = true
            @values[:show_stderr] = true
          end

          # Configure the cog to write __no output__ to the console, neither STDOUT nor STDERR
          #
          # #### Alias Methods
          # - `no_display!`
          # - `print_none!`
          # - `quiet!`
          #
          # #### See Also
          # - `display!`
          # - `no_show_stdout!`
          # - `no_show_stderr!`
          #
          #: () -> void
          def no_display!
            raise "⚠️ DEPRECATION: use no_display! instead of #{__callee__}" if __callee__.to_s.include?("print_")

            @values[:show_stdout] = false
            @values[:show_stderr] = false
          end

          # Check if the cog is configured to display any output while running
          #
          # #### See Also
          # - `display!`
          # - `no_display!`
          # - `show_stdout?`
          # - `show_stderr?`
          #
          #: () -> bool
          def display?
            show_stdout? || show_stderr?
          end

          alias_method(:quiet!, :no_display!)
          alias_method(:print_all!, :display!)
          alias_method(:print_none!, :no_display!)
          alias_method(:print_stdout!, :show_stdout!)
          alias_method(:no_print_stdout!, :no_show_stdout!)
          alias_method(:print_stderr!, :show_stderr!)
          alias_method(:no_print_stderr!, :no_show_stderr!)
        end

        # Input specification for the cmd cog
        #
        # The cmd cog requires a command to execute, optionally with arguments.
        # The command will be executed in the configured working directory.
        class Input < Cog::Input
          # The command to execute
          #
          #: String?
          attr_accessor :command

          # Arguments to pass to the command
          #
          #: Array[String]
          attr_accessor :args

          # Data to pass to command's standard input
          #
          #: String?
          attr_accessor :stdin

          #: () -> void
          def initialize
            super
            @args = []
          end

          # Validate that the input has all required parameters
          #
          # This method ensures that a command has been provided before the cmd cog executes.
          #
          # #### See Also
          # - `coerce`
          #
          #: () -> void
          def validate!
            raise Cog::Input::InvalidInputError, "'command' is required" unless command.present?
          end

          # Coerce the input from the return value of the input block
          #
          # If the input block returns a String, it will be used as the command value.
          # If the input block returns an Array, the first element will be used as the command
          # and the remaining elements will be used as arguments.
          #
          # #### See Also
          # - `validate!`
          #
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

        # Output from running the cmd cog
        #
        # Contains the standard output, standard error, and exit status from the executed command.
        # Includes JSON and text parsing capabilities via `WithJson` and `WithText` modules.
        class Output < Cog::Output
          include Cog::Output::WithJson
          include Cog::Output::WithNumber
          include Cog::Output::WithText

          # The standard output (STDOUT) from the command
          #
          #: String
          attr_reader :out

          # The standard error (STDERR) from the command
          #
          #: String
          attr_reader :err

          # The exit status of the command process
          #
          #: Process::Status
          attr_reader :status

          #: ( String, String, Process::Status) -> void
          def initialize(out, err, status)
            super()
            @out = out #: String
            @err = err #: String
            @status = status #: Process::Status
          end

          private

          def raw_text
            out
          end
        end

        #: (Input) -> Output
        def execute(input)
          config = @config #: as Config

          stdout_handler = config.show_stdout? ? ->(line) { $stdout.print(line) } : nil
          stderr_handler = config.show_stderr? ? ->(line) { $stderr.print(line) } : nil

          stdout, stderr, status = CommandRunner #: as untyped
            .execute(
              [input.command] + input.args,
              working_directory: config.valid_working_directory,
              stdin_content: input.stdin,
              stdout_handler: stdout_handler,
              stderr_handler: stderr_handler,
            )

          Output.new(stdout, stderr, status)
        end
      end
    end
  end
end
