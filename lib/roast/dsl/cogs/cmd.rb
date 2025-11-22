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

<<<<<<< HEAD
          # Check if the cog is configured to write its output to the console in raw form
          #
          #: () -> bool
          def raw_output?
            !!@values[:raw_output]
          end

          alias_method(:display!, :print_all!)
          alias_method(:no_display!, :print_none!)
=======
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
>>>>>>> c623a68 (Replace print_* config methods with show_* config methods for `cmd` cog)
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
          include Cog::Output::WithJson

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

          private

          def json_text
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
