# typed: true
# frozen_string_literal: true

module Roast
  module Cogs
    class Agent < Cog
      module Providers
        class Pi < Provider
          module Messages
            # Represents a tool call made by the Pi agent
            #
            # In Pi's JSON protocol, tool calls appear as `toolcall_end` events within
            # `message_update` messages, containing the tool name, id, and arguments.
            class ToolCallMessage
              #: String?
              attr_reader :id

              #: String?
              attr_reader :name

              #: Hash[Symbol, untyped]
              attr_reader :arguments

              #: (id: String?, name: String?, arguments: Hash[Symbol, untyped]) -> void
              def initialize(id:, name:, arguments:)
                @id = id
                @name = name
                @arguments = arguments
              end

              #: () -> String?
              def format
                return unless name

                format_method_name = "format_#{name.to_s.downcase}".to_sym
                return send(format_method_name) if respond_to?(format_method_name, true)

                format_unknown
              end

              # Truncate long formatted tool-call strings to keep terminal output to generally one line, accounting for logger prefixing.
              TRUNCATE_LIMIT = 45

              private

              # Formats a bash tool call.
              #
              # Input fields:
              #   :command (String) – shell command to execute   [required]
              #
              # Output: "BASH <command>", with :command truncated to TRUNCATE_LIMIT
              # chars. A missing command renders the bare "BASH".
              #
              # Examples:
              #   BASH ls -la
              #   BASH
              #
              #: () -> String
              def format_bash
                command = truncate(arguments[:command])
                command.empty? ? "BASH" : "BASH #{command}"
              end

              # Formats a tool call for which Roast has no dedicated formatter.
              #
              # Output: "<NAME> <key>: <value>, ..." – the upcased tool name, then each
              # argument as "<key>: <inspected value>" joined with ", ". Every value is
              # truncated to TRUNCATE_LIMIT chars so one large argument can't flood the
              # line; keys are always shown. No arguments renders the bare "<NAME>".
              #
              # Examples:
              #   WEB_SEARCH query: "ruby pluralize", max_results: 5
              #   DEPLOY
              #
              #: () -> String
              def format_unknown
                label = name.to_s.upcase
                return label if arguments.empty?

                details = arguments.map { |key, value| "#{key}: #{truncate(value.inspect)}" }.join(", ")
                "#{label} #{details}"
              end

              # Truncates to TRUNCATE_LIMIT chars, appending "..." when cut. nil -> "".
              #
              #: (String?) -> String
              def truncate(str)
                s = str.to_s
                s.length > TRUNCATE_LIMIT ? "#{s[0...TRUNCATE_LIMIT - 3]}..." : s
              end
            end
          end
        end
      end
    end
  end
end
