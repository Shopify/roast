# typed: true
# frozen_string_literal: true

module Roast
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
              format_method_name = "format_#{name}".to_sym
              return send(format_method_name) if respond_to?(format_method_name, true)

              format_unknown
            end

            # Truncate long formatted tool-use strings to keep terminal output to generally one line, accounting for logger prefixing.
            TRUNCATE_LIMIT = 45

            private

            # Truncates a string to at most TRUNCATE_LIMIT characters, appending
            # "..." when the string is cut. The returned string — including the
            # ellipsis — is guaranteed to be ≤ TRUNCATE_LIMIT characters.
            #
            # nil is coerced to "" (so callers needn't nil-check).
            # Strings at or below the limit are returned unchanged.
            #
            # Input:
            #   str (String?) – the string to truncate
            #
            # Output: the (possibly shortened) string
            #
            # Examples:
            #   truncate("ls -la")           # => "ls -la"
            #   truncate("a" * 50)           # => "aaa...aaa..." (45 chars)
            #   truncate(nil)                # => ""
            #
            #: (String?) -> String
            def truncate(str)
              s = str.to_s
              s.length > TRUNCATE_LIMIT ? "#{s[0...TRUNCATE_LIMIT - 3]}..." : s
            end

            # Formats a Bash tool-use line.
            #
            # Input fields:
            #   :command     (String) – shell command to execute      [required]
            #   :description (String) – human-readable label          [optional]
            #
            # Output: "BASH <command>", with " (<description>)" appended when
            # :description is present. :command is truncated to TRUNCATE_LIMIT chars.
            #
            # Examples:
            #   BASH ls -la (List directory contents)
            #   BASH ls -la
            #
            #: () -> String
            def format_bash
              command = truncate(input[:command])
              description = input[:description]
              label = command.empty? ? "BASH" : "BASH #{command}"
              description ? "#{label} (#{description})" : label
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
