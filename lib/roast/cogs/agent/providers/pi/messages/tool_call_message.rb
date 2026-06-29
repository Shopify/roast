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

              TRUNCATE_LIMIT = 45

              private

              #: () -> String
              def format_bash
                command = truncate(arguments[:command])
                command.empty? ? "BASH" : "BASH #{command}"
              end

              #: () -> String
              def format_read
                path = arguments[:path]
                path.to_s.empty? ? "READ" : "READ #{path}"
              end

              #: () -> String
              def format_write
                path, content = arguments.values_at(:path, :content)
                lines = content.to_s.lines
                preview = truncate(lines.first.to_s.strip)
                count = lines.length
                line_label = count == 1 ? "line" : "lines"
                "WRITE #{path} \"#{preview}\" (+#{count} #{line_label})"
              end

              #: () -> String
              def format_edit
                path = arguments[:path]
                edits = arguments[:edits] || []
                count = edits.length
                edit_label = count == 1 ? "edit" : "edits"
                "EDIT #{path} (#{count} #{edit_label})"
              end

              #: () -> String
              def format_unknown
                "UNKNOWN [#{name}] #{arguments.inspect}"
              end

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
