# frozen_string_literal: true
# typed: true

require "open3"

module Roast
  module DSL
    module Cogs
      class Cmd < Roast::DSL::Cog
        include Storable

        DEFAULT_NAME = :cmd

        # @override
        #: () -> String
        attr_reader :output

        #: (String | Symbol | nil) -> void
        def initialize(name_or_cmd = nil)
          case name_or_cmd
          when String
            @name = DEFAULT_NAME
            @cmd = name_or_cmd
            @should_store = false
          when Symbol
            @name = name_or_cmd
            @cmd = nil
            @should_store = true
          else
            raise ArgumentError, "cmd() requires a string or symbol, got: #{name_or_cmd.class}"
          end
        end

        # @override
        #: () -> void
        def on_invoke
          run unless @should_store # If its unstored, e.g. plain cmd('echo "ha"'), then run it in place
        end

        # @override
        #: () -> (Roast::DSL::Cog::Cmd | String)
        def invoke_return
          if @should_store
            self
          else
            @output
          end
        end

        # @override
        #: () -> String
        def store_id
          @name
        end

        # @override
        #: () -> bool
        def store?
          @should_store
        end

        # TODO: Accept arg list, not just string
        #: (String) -> void
        def set(cmd)
          unless @cmd.nil?
            raise "Command for '#{@name}' already set to '#{@cmd}'"
          end

          @cmd = cmd
        end

        #: (String?) -> String
        def run(cmd = nil)
          set(cmd) unless cmd.nil?

          @output, _err, _status = Roast::Helpers::CmdRunner.capture3(@cmd)

          Roast::Helpers::Logger.info @output
        end
      end
    end
  end
end
