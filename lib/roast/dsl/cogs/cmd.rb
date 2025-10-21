# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
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

        class Config < Cog::Config
          #: () -> void
          def print_all!
            @values[:print_stdout] = true
            @values[:print_stderr] = true
          end

          def print_none!
            @values[:print_stdout] = false
            @values[:print_stderr] = false
          end

          #: () -> void
          def print_stdout!
            @values[:print_stdout] = true
          end

          #: () -> void
          def no_print_stdout!
            @values[:print_stdout] = false
          end

          #: () -> void
          def print_stderr!
            @values[:print_stderr] = true
          end

          #: () -> void
          def no_print_stderr!
            @values[:print_stderr] = false
          end

          #: () -> bool
          def print_stdout?
            !!@values[:print_stdout]
          end

          #: () -> bool
          def print_stderr?
            !!@values[:print_stderr]
          end

          alias_method(:display!, :print_all!)
          alias_method(:no_display!, :print_none!)
        end

        #: (Input) -> Output
        def execute(input)
          config = @config #: as Config
          result = T.unsafe(Roast::Helpers::CmdRunner).popen3(input.command, *input.args) do |stdin, stdout, stderr, wait_thread|
            stdin.close
            command_output = ""
            command_error = ""

            # Thread to read and accumulate stdout
            stdout_thread = Thread.new do
              stdout.each_line do |line|
                command_output += line
                $stdout.puts(line) if config.print_stdout?
              end
            rescue IOError => e
              Roast::Helpers::Logger.debug("IOError while reading stdout: #{e.message}")
            end

            # Thread to read and accumulate stderr
            stderr_thread = Thread.new do
              stderr.each_line do |line|
                command_error += line
                $stderr.puts(line) if config.print_stderr?
              end
            rescue IOError => e
              Roast::Helpers::Logger.debug("IOError while reading stderr: #{e.message}")
            end

            # Wait for threads to finish
            stdout_thread.join
            stderr_thread.join

            [command_output, command_error, wait_thread.value]
          end #: as [String, String, Process::Status]

          Output.new(*result)
        end
      end
    end
  end
end
