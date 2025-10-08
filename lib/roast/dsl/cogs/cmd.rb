# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
        class Output
          #: String?
          attr_reader :output

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
            @output = output
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
        end

        use_config_class Config

        #: () -> void
        def execute
          result = Output.new(*Roast::Helpers::CmdRunner.capture3(input))
          puts result.output if @config.print_all?
          result
        end
      end
    end
  end
end
