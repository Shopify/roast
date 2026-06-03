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

            private

            #: (String?) -> String
            def truncate(str)
              char_limit = 50
              s = str.to_s
              s.length > char_limit ? "#{s[0..char_limit - 3]}..." : s
            end

            #: () -> String
            def format_taskoutput
              task_id = truncate(input[:task_id])
              details = [
                ("blocking" if input[:block]),
                ("#{input[:timeout]}ms" if input[:timeout]),
              ].compact.join(" · ")
              "TASKOUTPUT #{task_id}\n  #{details}"
            end

            #: () -> String
            def format_agent
              description = truncate(input[:description])
              details = [
                ("background" if input[:run_in_background]),
                input[:subagent_type],
              ].compact.join(" · ")
              "AGENT #{description}\n  #{details}"
            end

            #: () -> String
            def format_task
              description = truncate(input[:description])
              details = [
                ("background" if input[:run_in_background]),
                input[:subagent_type],
                input[:model],
              ].compact.join(" · ")
              "TASK #{description}\n  #{details}"
            end

            #: () -> String
            def format_skill
              "SKILL #{input[:skill]}\n  #{truncate(input[:args])}"
            end

            #: () -> String
            def format_todowrite
              todos = input[:todos] || []
              counts = todos
                .group_by { |t| t[:status] || t["status"] }
                .transform_values(&:length)
              summary = counts.map { |status, n| "#{n} #{status}" }.join(" · ")
              "TODOWRITE #{todos.length} todos\n  #{summary}"
            end

            #: () -> String
            def format_edit
              file_path = input[:file_path]
              old_lines = input[:old_string].to_s.lines
              new_lines = input[:new_string].to_s.lines
              old_hint = truncate(old_lines.first.to_s.strip)
              new_hint = truncate(new_lines.first.to_s.strip)
              old_suffix = old_lines.length > 1 ? " (+#{old_lines.length - 1} lines)" : ""
              new_suffix = new_lines.length > 1 ? " (+#{new_lines.length - 1} lines)" : ""
              replace_all = input[:replace_all] ? " · replace_all" : ""
              "EDIT #{file_path}#{replace_all}\n  - \"#{old_hint}\"#{old_suffix}\n  + \"#{new_hint}\"#{new_suffix}"
            end

            #: () -> String
            def format_write
              file_path = input[:file_path]
              preview = truncate(input[:content].to_s.lines.first.to_s.strip)
              "WRITE #{file_path}\n  #{preview}"
            end

            #: () -> String
            def format_grep
              modifiers = [
                ("glob=#{input[:glob]}" if input[:glob]),
                ("type=#{input[:type]}" if input[:type]),
                ("-i" if input[:i]),
              ].compact.join(" · ")
              second_line = modifiers.empty? ? nil : "  #{modifiers}"
              ["GREP \"#{truncate(input[:pattern])}\" #{input[:path]}", second_line].compact.join("\n")
            end

            #: () -> String
            def format_glob
              "GLOB #{input[:pattern]}\n  #{input[:path]}"
            end

            #: () -> String
            def format_read
              file_path = input[:file_path]
              limit = input[:limit]
              offset = input[:offset]
              details = if limit
                offset ||= 0
                "lines #{offset + 1}–#{offset + limit}"
              end
              details ? "READ #{file_path}\n  #{details}" : "READ #{file_path}"
            end

            #: () -> String
            def format_bash
              command = truncate(input[:command])
              description = input[:description]
              description ? "BASH #{command}\n  #{description}" : "BASH #{command}"
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
