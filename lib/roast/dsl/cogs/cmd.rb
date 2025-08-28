# frozen_string_literal: true
# typed: true

require "open3"

module Roast
  module DSL
    module Cogs
      class Cmd < Roast::DSL::Cog
        DEFAULT_NAME = :cmd

        #: (String | Symbol | nil) -> void
        def initialize(name_or_cmd = nil)
          case name_or_cmd
          when String
            @name = DEFAULT_NAME
            @cmd = name_or_cmd
          when Symbol
            @name = name_or_cmd
            @cmd = nil
          when nil
            @name = DEFAULT_NAME
            @cmd = nil
          else
            raise ArgumentError, "cmd() requires a string or symbol, got: #{name_or_cmd.class}"
          end

          super(@name)
        end

        # @override
        #: () -> void
        def on_invoke
          run(@cmd) unless @cmd.nil?
        end

        #: (String) -> String
        def run(cmd)
          @output, _err, _status = Roast::Helpers::CmdRunner.capture3(cmd)

          Roast::Helpers::Logger.info @output
        end

        # @override
        #: () -> String
        attr_reader :output
      end
    end
  end
end
