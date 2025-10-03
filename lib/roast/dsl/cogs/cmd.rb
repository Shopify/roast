# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Cmd < Cog
        class Output
          attr_reader :output
          attr_reader :err
          attr_reader :status

          def initialize(output, error, status)
            @output = output
            @err = error
            @status = status
          end
        end

        class Config < Cog::Config
          def print_all!
            @values[:print_all] = true
          end

          def print_all?
            !!@values[:print_all]
          end
        end

        use_config_class Config

        def execute
          result = Output.new(*Roast::Helpers::CmdRunner.capture3(input))
          puts result.output if @config.print_all?
          result
        end
      end
    end
  end
end
