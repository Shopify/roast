# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          class ToolUse
            #: Symbol
            attr_reader :name

            #: Hash[Symbol, untyped]
            attr_reader :input

            #: (name: Symbol, input: Hash[Symbol, untyped]) -> void
            def initialize(name:, input:)
              @name = name
              @input = input
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
              "BASH #{input[:command]}"
            end

            #: () -> String
            def format_read
              "READ #{input[:path]}"
            end

            #: () -> String
            def format_edit
              "EDIT #{input[:path]}"
            end

            #: () -> String
            def format_write
              "WRITE #{input[:path]}"
            end

            #: () -> String
            def format_grep
              "GREP #{input[:pattern]} #{input[:path]}"
            end

            #: () -> String
            def format_find
              "FIND #{input[:path]} #{input[:pattern]}"
            end

            #: () -> String
            def format_ls
              "LS #{input[:path]}"
            end

            #: () -> String
            def format_unknown
              "UNKNOWN [#{name}] #{input.inspect}"
            end
          end
        end
      end
    end
  end
end
