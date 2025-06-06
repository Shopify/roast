# frozen_string_literal: true

module Roast
  module Tools
    module Helpers
      module CodingAgentMessageFormatter
        extend self

        def format_messages(json)
          messages = json.dig("message", "content")
          messages.map(&method(:format_message))
        end

        private

        def format_message(message)
          case message["type"]
          when "text"
            format_text(message["text"])
          when "tool_use"
            name = message["name"]
            input = message["input"].except("description", "old_string", "new_string")
            case name
            when "Task"
              "→ #{name}#{format_task_input(input)}"
            when "TodoWrite"
              "→ #{name}#{format_todo_write_input(input)}"
            when "Bash", "Read", "Edit"
              "→ #{name}(#{format_arguments(input)})"
            else
              "→ #{name} #{format_text(input.to_yaml)}"
            end
          when "tool_result"
            # Ignore these message types
          else
            message.except("id").to_yaml
          end
        end

        def format_text(text)
          text.lines.map do |line|
            "\t#{line}"
          end.join.lstrip
        end

        def format_task_input(input)
          prompt = input["prompt"].lines.filter { |line| !line.blank? }.map { |line| "\t#{line}" }.join
          args = format_arguments(input.except("prompt"))
          "(#{args})\n#{prompt}"
        end

        def format_todo_write_input(input)
          todos = input["todos"].map(&method(:format_todo_write_input_item)).join("\n")
          args = format_arguments(input.except("todos"))
          "(#{args})\n#{todos}"
        end

        def format_todo_write_input_item(item)
          id = item["id"]
          content = item["content"]
          status = case item["status"]
          when "pending"
            "[ ]"
          when "in_progress"
            "[-]"
          when "completed"
            "[x]"
          end
          "\t#{id}. #{status} #{content}"
        end

        def format_arguments(arguments)
          if arguments.length == 1
            arguments.first[1].to_json
          else
            arguments.map do |key, value|
              "#{key}: #{value.to_json}"
            end.join(", ")
          end
        end
      end
    end
  end
end
