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
              timeout_ms = input[:timeout]
              timeout_str = if timeout_ms
                secs = timeout_ms / 1000.0
                secs == secs.to_i ? "#{secs.to_i}s timeout" : "#{secs}s timeout"
              end
              details = [("sync" if input[:block]), timeout_str].compact.join(" · ")
              details.empty? ? "TASKOUTPUT ##{task_id}" : "TASKOUTPUT ##{task_id} (#{details})"
            end

            #: () -> String
            def format_agent
              description = truncate(input[:description])
              details = [
                ("background" if input[:run_in_background]),
                input[:subagent_type],
              ].compact.join(" · ")
              details.empty? ? "AGENT #{description}" : "AGENT #{description} (#{details})"
            end

            #: () -> String
            def format_task
              description = truncate(input[:description])
              details = [
                ("background" if input[:run_in_background]),
                input[:subagent_type],
                input[:model],
              ].compact.join(" · ")
              details.empty? ? "TASK #{description}" : "TASK #{description} (#{details})"
            end

            #: () -> String
            def format_skill
              args = input[:args]
              args ? "SKILL #{input[:skill]} (#{truncate(args)})" : "SKILL #{input[:skill]}"
            end

            #: () -> String
            def format_todowrite
              todos = input[:todos] || []
              counts = todos
                .group_by { |t| t[:status] || t["status"] }
                .transform_values(&:length)
              summary = counts.map { |status, n| "#{n} #{status}" }.join(" · ")
              summary.empty? ? "TODOWRITE #{todos.length} todos" : "TODOWRITE #{todos.length} todos (#{summary})"
            end

            #: () -> String
            def format_edit
              file_path = input[:file_path]
              old_lines = input[:old_string].to_s.lines
              new_lines = input[:new_string].to_s.lines
              replace_all = input[:replace_all] ? " · replace_all" : ""
              old_desc = old_lines.length == 1 ? "\"#{truncate(old_lines.first.to_s.strip)}\"" : "#{old_lines.length} lines"
              new_desc = new_lines.length == 1 ? "\"#{truncate(new_lines.first.to_s.strip)}\"" : "#{new_lines.length} lines"
              "EDIT #{file_path}#{replace_all}\n  - #{old_desc}\n  + #{new_desc}"
            end

            #: () -> String
            def format_write
              file_path = input[:file_path]
              lines = input[:content].to_s.lines
              preview = truncate(lines.first.to_s.strip)
              extra = lines.length - 1
              suffix = if extra > 0
                " (+#{extra} #{extra == 1 ? "line" : "lines"})"
              else
                ""
              end
              "WRITE #{file_path} \"#{preview}\"#{suffix}"
            end

            #: () -> String
            def format_grep
              modifiers = [
                ("glob=#{input[:glob]}" if input[:glob]),
                ("type=#{input[:type]}" if input[:type]),
                ("-i" if input[:i]),
              ].compact.join(" · ")
              base = "GREP \"#{truncate(input[:pattern])}\" #{input[:path]}"
              modifiers.empty? ? base : "#{base} (#{modifiers})"
            end

            #: () -> String
            def format_glob
              path = input[:path]
              path ? "GLOB #{input[:pattern]} (in #{path})" : "GLOB #{input[:pattern]}"
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
              details ? "READ #{file_path} (#{details})" : "READ #{file_path}"
            end

            #: () -> String
            def format_bash
              command = truncate(input[:command])
              description = input[:description]
              description ? "BASH #{command} (#{description})" : "BASH #{command}"
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
