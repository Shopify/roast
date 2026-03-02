# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          # Formats a Pi tool call for progress display
          #
          # Pi tool calls come from `toolcall_end` events in `message_update` messages.
          # Each tool has a name and arguments hash. Known tools get specialized formatting;
          # unknown tools get a generic display.
          class ToolUse
            #: String
            attr_reader :name

            #: Hash[Symbol, untyped]
            attr_reader :arguments

            #: (name: String, arguments: Hash[Symbol, untyped]) -> void
            def initialize(name:, arguments:)
              @name = name
              @arguments = arguments
            end

            #: () -> String
            def format
              format_method_name = "format_#{name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            private

            #: () -> String
            def format_bash
              command = arguments[:command] || arguments[:cmd]
              "BASH: #{command}"
            end

            #: () -> String
            def format_read
              path = arguments[:path]
              "READ: #{path}"
            end

            #: () -> String
            def format_write
              path = arguments[:path]
              "WRITE: #{path}"
            end

            #: () -> String
            def format_edit
              path = arguments[:path]
              "EDIT: #{path}"
            end

            #: () -> String
            def format_grep
              pattern = arguments[:pattern] || arguments[:query]
              path = arguments[:path]
              "GREP: #{pattern}#{path ? " in #{path}" : ""}"
            end

            #: () -> String
            def format_find
              path = arguments[:path] || arguments[:dir]
              pattern = arguments[:pattern] || arguments[:name]
              "FIND: #{pattern}#{path ? " in #{path}" : ""}"
            end

            #: () -> String
            def format_ls
              path = arguments[:path]
              "LS: #{path}"
            end

            #: () -> String
            def format_unknown
              "TOOL [#{name}] #{arguments.inspect}"
            end
          end
        end
      end
    end
  end
end
