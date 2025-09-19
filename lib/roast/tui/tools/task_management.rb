# typed: true
# frozen_string_literal: true

require "json"

module Roast
  module TUI
    module Tools
      class TaskManagement
        # Todo list management tool
        class Todo < Base
          # Class-level storage for todos
          @@todos = []
          @@todo_mutex = Mutex.new

          def initialize
            super(
              name: "todo",
              description: "Manage a task list for the current session",
              parameters: {
                type: "object",
                properties: {
                  todos: Base.array_param(
                    "The updated todo list",
                    items: {
                      type: "object",
                      properties: {
                        content: Base.string_param("Task description (imperative form)", required: true),
                        activeForm: Base.string_param("Task description (present continuous form)", required: true),
                        status: Base.string_param(
                          "Task status",
                          enum: ["pending", "in_progress", "completed"],
                          required: true
                        ),
                        priority: Base.string_param(
                          "Task priority",
                          enum: ["low", "medium", "high"],
                          default: "medium"
                        ),
                        tags: Base.array_param(
                          "Task tags/categories",
                          items: { type: "string" }
                        ),
                        created_at: Base.string_param("Creation timestamp"),
                        updated_at: Base.string_param("Last update timestamp"),
                        completed_at: Base.string_param("Completion timestamp")
                      },
                      required: ["content", "status", "activeForm"]
                    },
                    required: true
                  ),
                  action: Base.string_param(
                    "Action to perform",
                    enum: ["update", "clear", "show", "stats"],
                    default: "update"
                  )
                },
                required: ["todos"]
              }
            )
          end

          def parallel_safe?
            false
          end

          def perform(arguments, context)
            action = arguments["action"] || "update"
            
            case action
            when "update"
              update_todos(arguments["todos"], context)
            when "clear"
              clear_todos(context)
            when "show"
              show_todos(context)
            when "stats"
              show_stats(context)
            else
              raise ValidationError, "Unknown action: #{action}"
            end
          end

          private

          def update_todos(new_todos, context)
            @@todo_mutex.synchronize do
              # Validate todo list rules
              validate_todos!(new_todos)
              
              # Update timestamps
              now = Time.now.iso8601
              
              new_todos.each do |todo|
                # Set created_at for new todos
                existing = @@todos.find { |t| t["content"] == todo["content"] }
                if existing
                  todo["created_at"] = existing["created_at"]
                  
                  # Set completed_at if status changed to completed
                  if existing["status"] != "completed" && todo["status"] == "completed"
                    todo["completed_at"] = now
                  elsif existing["status"] == "completed" && todo["status"] != "completed"
                    todo.delete("completed_at")
                  else
                    todo["completed_at"] = existing["completed_at"]
                  end
                else
                  todo["created_at"] = now
                end
                
                todo["updated_at"] = now
              end
              
              @@todos = new_todos
            end
            
            format_todo_list(@@todos, context)
          end

          def clear_todos(context)
            @@todo_mutex.synchronize do
              @@todos = []
            end
            
            "Todo list cleared"
          end

          def show_todos(context)
            format_todo_list(@@todos, context)
          end

          def show_stats(context)
            stats = calculate_stats(@@todos)
            format_stats(stats)
          end

          def validate_todos!(todos)
            # Ensure exactly one task is in progress
            in_progress_count = todos.count { |t| t["status"] == "in_progress" }
            
            if in_progress_count > 1
              in_progress_tasks = todos.select { |t| t["status"] == "in_progress" }
                                       .map { |t| t["content"] }
                                       .join(", ")
              raise ValidationError, "Only one task can be in_progress at a time. Found: #{in_progress_tasks}"
            end
            
            # Validate required fields
            todos.each_with_index do |todo, index|
              if todo["content"].to_s.strip.empty?
                raise ValidationError, "Task #{index + 1}: content cannot be empty"
              end
              
              if todo["activeForm"].to_s.strip.empty?
                raise ValidationError, "Task #{index + 1}: activeForm cannot be empty"
              end
              
              unless %w[pending in_progress completed].include?(todo["status"])
                raise ValidationError, "Task #{index + 1}: invalid status '#{todo["status"]}'"
              end
            end
          end

          def format_todo_list(todos, context)
            return "No tasks in todo list" if todos.empty?
            
            output = []
            output << CLI::UI::Frame.open("Todo List", color: :blue)
            
            # Group by status
            by_status = todos.group_by { |t| t["status"] }
            
            # Show in progress first
            if by_status["in_progress"]
              output << CLI::UI.fmt("{{bold:{{yellow:In Progress}}}}")
              by_status["in_progress"].each do |todo|
                output << format_todo_item(todo, true)
              end
              output << ""
            end
            
            # Show pending
            if by_status["pending"]
              output << CLI::UI.fmt("{{bold:Pending}}")
              by_status["pending"].each do |todo|
                output << format_todo_item(todo)
              end
              output << ""
            end
            
            # Show completed
            if by_status["completed"]
              output << CLI::UI.fmt("{{bold:{{green:Completed}}}}")
              by_status["completed"].each do |todo|
                output << format_todo_item(todo)
              end
            end
            
            CLI::UI::Frame.close
            
            # Add summary
            summary = calculate_stats(todos)
            output << "\n"
            output << CLI::UI.fmt("Summary: {{cyan:#{summary[:total]} total}}, ")
            output << CLI::UI.fmt("{{yellow:#{summary[:in_progress]} in progress}}, ")
            output << CLI::UI.fmt("{{blue:#{summary[:pending]} pending}}, ")
            output << CLI::UI.fmt("{{green:#{summary[:completed]} completed}}")
            
            if summary[:completion_rate] > 0
              output << CLI::UI.fmt(" ({{bold:#{summary[:completion_rate]}% complete}})")
            end
            
            output.join("\n")
          end

          def format_todo_item(todo, active = false)
            icon = case todo["status"]
                  when "completed" then "✓"
                  when "in_progress" then "▶"
                  else "○"
                  end
            
            priority_color = case todo["priority"]
                           when "high" then :red
                           when "low" then :cyan
                           else :default
                           end
            
            text = active ? todo["activeForm"] : todo["content"]
            
            line = "  #{icon} #{text}"
            
            # Add priority indicator if high
            if todo["priority"] == "high"
              line = CLI::UI.fmt("{{red:#{line}}}")
            elsif todo["status"] == "completed"
              line = CLI::UI.fmt("{{gray:#{line}}}")
            end
            
            # Add tags if present
            if todo["tags"] && !todo["tags"].empty?
              tags = todo["tags"].map { |t| "[#{t}]" }.join(" ")
              line += CLI::UI.fmt(" {{cyan:#{tags}}}")
            end
            
            line
          end

          def calculate_stats(todos)
            total = todos.length
            pending = todos.count { |t| t["status"] == "pending" }
            in_progress = todos.count { |t| t["status"] == "in_progress" }
            completed = todos.count { |t| t["status"] == "completed" }
            
            completion_rate = total > 0 ? (completed.to_f / total * 100).round : 0
            
            # Calculate time stats
            if todos.any? { |t| t["created_at"] }
              oldest = todos.map { |t| Time.parse(t["created_at"]) rescue nil }.compact.min
              newest = todos.map { |t| Time.parse(t["created_at"]) rescue nil }.compact.max
              
              completed_todos = todos.select { |t| t["status"] == "completed" && t["completed_at"] }
              if completed_todos.any?
                completion_times = completed_todos.map do |t|
                  begin
                    completed = Time.parse(t["completed_at"])
                    created = Time.parse(t["created_at"])
                    completed - created
                  rescue
                    nil
                  end
                end.compact
                
                avg_completion_time = completion_times.any? ? completion_times.sum / completion_times.length : nil
              end
            end
            
            {
              total: total,
              pending: pending,
              in_progress: in_progress,
              completed: completed,
              completion_rate: completion_rate,
              oldest_task: oldest,
              newest_task: newest,
              avg_completion_time: avg_completion_time
            }
          end

          def format_stats(stats)
            lines = []
            lines << CLI::UI::Frame.open("Todo Statistics", color: :cyan)
            
            lines << CLI::UI.fmt("Total tasks: {{bold:#{stats[:total]}}}")
            lines << CLI::UI.fmt("  Pending: {{blue:#{stats[:pending]}}}")
            lines << CLI::UI.fmt("  In Progress: {{yellow:#{stats[:in_progress]}}}")
            lines << CLI::UI.fmt("  Completed: {{green:#{stats[:completed]}}}")
            lines << ""
            lines << CLI::UI.fmt("Completion rate: {{bold:#{stats[:completion_rate]}%}}")
            
            if stats[:avg_completion_time]
              duration = format_duration(stats[:avg_completion_time])
              lines << CLI::UI.fmt("Average completion time: {{bold:#{duration}}}")
            end
            
            if stats[:oldest_task]
              age = format_duration(Time.now - stats[:oldest_task])
              lines << CLI::UI.fmt("Oldest task age: {{bold:#{age}}}")
            end
            
            CLI::UI::Frame.close
            
            lines.join("\n")
          end

          def format_duration(seconds)
            return "0s" if seconds < 1
            
            days = (seconds / 86400).to_i
            hours = ((seconds % 86400) / 3600).to_i
            minutes = ((seconds % 3600) / 60).to_i
            secs = (seconds % 60).to_i
            
            parts = []
            parts << "#{days}d" if days > 0
            parts << "#{hours}h" if hours > 0
            parts << "#{minutes}m" if minutes > 0
            parts << "#{secs}s" if secs > 0 && parts.empty?
            
            parts.join(" ")
          end

          class << self
            def get_todos
              @@todos.dup
            end

            def add_todo(content, active_form = nil, priority = "medium", tags = [])
              todo = {
                "content" => content,
                "activeForm" => active_form || "Working on: #{content}",
                "status" => "pending",
                "priority" => priority,
                "tags" => tags,
                "created_at" => Time.now.iso8601,
                "updated_at" => Time.now.iso8601
              }
              
              @@todo_mutex.synchronize do
                @@todos << todo
              end
              
              todo
            end

            def update_todo_status(content, new_status)
              @@todo_mutex.synchronize do
                todo = @@todos.find { |t| t["content"] == content }
                if todo
                  todo["status"] = new_status
                  todo["updated_at"] = Time.now.iso8601
                  
                  if new_status == "completed"
                    todo["completed_at"] = Time.now.iso8601
                  end
                  
                  true
                else
                  false
                end
              end
            end

            def clear_completed
              @@todo_mutex.synchronize do
                @@todos.reject! { |t| t["status"] == "completed" }
              end
            end
          end
        end

        class << self
          def register_all(registry)
            registry.register(
              name: "todo",
              description: Todo.new.description,
              parameters: Todo.new.parameters,
              parallel_safe: false
            ) { |args| Todo.new.execute(args) }
          end
        end
      end
    end
  end
end