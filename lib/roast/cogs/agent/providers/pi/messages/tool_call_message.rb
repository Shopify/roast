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
                @arguments = arguments.is_a?(Hash) ? arguments : {}
              end

              #: () -> String?
              def format
                return unless name

                format_method_name = "format_#{name.to_s.downcase}".to_sym
                return send(format_method_name) if respond_to?(format_method_name, true)

                format_unknown
              rescue StandardError
                format_unknown
              end

              # Truncates each value in a formatted tool-call string to keep terminal output concise.
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

              # Formats a read tool call.
              #
              # Input fields:
              #   :path   (String)  – file to read              [required]
              #   :offset (Integer) – 1-indexed first line       [optional]
              #   :limit  (Integer) – maximum number of lines    [optional]
              #
              # Output: "READ <path>", with a line range appended when :offset and/or
              # :limit is given:
              #   :limit >= 1  → " (lines <start>–<end>)", start = :offset (default 1),
              #                  end = start + :limit - 1
              #   :offset only → " (from line <offset>)" (reads to end of file); also the
              #                  fallback when :limit <= 0, which has no sensible range
              # With neither, the bare "READ <path>". A missing path renders "READ".
              #
              # Examples:
              #   READ lib/roast.rb (lines 30–80)
              #   READ lib/roast.rb (from line 30)
              #   READ lib/roast.rb
              #
              #: () -> String
              def format_read
                path, offset, limit = arguments.values_at(:path, :offset, :limit)
                path = path.to_s
                details = if limit&.positive?
                  offset ||= 1
                  "lines #{offset}–#{offset + limit - 1}"
                elsif offset
                  "from line #{offset}"
                end
                label = path.empty? ? "READ" : "READ #{path}"
                details ? "#{label} (#{details})" : label
              end

              # Formats a write tool call.
              #
              # Input fields:
              #   :path    (String) – file to write   [required]
              #   :content (String) – file contents   [required]
              #
              # Output: 'WRITE <path> "<preview>" (+<n> <line|lines>)' – <preview> is the
              # first line of :content (stripped, truncated to TRUNCATE_LIMIT chars) and
              # <n> the number of lines written. The content summary is appended only
              # when :content is present; a missing path renders the bare "WRITE".
              #
              # Examples:
              #   WRITE lib/roast.rb "class Roast" (+10 lines)
              #   WRITE config/app.yml "enabled: true" (+1 line)
              #   WRITE lib/roast.rb
              #   WRITE
              #
              #: () -> String
              def format_write
                path, content = arguments.values_at(:path, :content)
                path = path.to_s
                label = path.empty? ? "WRITE" : "WRITE #{path}"
                return label if content.nil?

                lines = content.to_s.lines
                preview = truncate(lines.first.to_s.strip)
                count = lines.length
                "#{label} \"#{preview}\" (+#{count} #{"line".pluralize(count)})"
              end

              # Formats a tool call for which Roast has no dedicated formatter.
              #
              # Output: "<NAME> <key>: <value>, ..." – the upcased tool name, then each
              # argument as "<key>: <inspected value>", ordered shortest pair first so the
              # most compact arguments stay visible, joined with ", ". Every value is
              # truncated to TRUNCATE_LIMIT chars so one large argument can't flood the
              # line; keys are always shown. No arguments renders the bare "<NAME>".
              #
              # Examples:
              #   WEB_SEARCH max_results: 5, query: "ruby pluralize"
              #   DEPLOY
              #
              #: () -> String
              def format_unknown
                label = name.to_s.upcase
                return label if arguments.empty?

                details = arguments.map { |key, value| "#{key}: #{truncate(value.inspect)}" }.sort_by { |s| [s.length, s] }.join(", ")
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
