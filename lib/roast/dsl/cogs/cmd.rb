# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
        class Output
          #: String?
          attr_reader :command_output

          #: String?
          attr_reader :err

          #: Process::Status?
          attr_reader :status

          #: (
          #|  String? output,
          #|  String? error,
          #|  Process::Status? status
          #| ) -> void
          def initialize(output, error, status)
            @command_output = output
            @err = error
            @status = status
          end
        end

        class Config < Cog::Config
          #: () -> void
          def print_all!
            @values[:print_all] = true
          end

          #: () -> bool
          def print_all?
            !!@values[:print_all]
          end

          def display!
            print_all!
          end
        end

        #: (String) -> Output
        def execute(input)
          config = @config #: as Config
          result = Output.new(*Roast::Helpers::CmdRunner.capture3(input))
          puts result.command_output if config.print_all?
          result
        end
      end
    end
  end
end
