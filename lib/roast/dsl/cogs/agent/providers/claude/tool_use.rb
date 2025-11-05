# typed: true
# frozen_string_literal: true

module Roast
  module DSL
    module Cogs
      class Agent < Cog
        module Providers
          class Claude < Provider
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
                format_method_name = "format_#{@name.downcase}".to_sym
                return send(format_method_name) if respond_to?(format_method_name, true)

                format_unknown
              end

              private

              #: () -> String
              def format_bash
                "BASH #{@input.inspect}"
              end

              #: () -> String
              def format_unknown
                "UNKNOWN #{@input.inspect}"
              end
            end
          end
        end
      end
    end
  end
end
