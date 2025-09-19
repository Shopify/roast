# typed: true
# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module Roast
  module TUI
    class WorkflowManager
      HISTORY_FILE = ".roast_workflow_history.json"
      WORKFLOW_EXTENSIONS = [".yml", ".yaml"].freeze

      attr_reader :current_directory, :history

      def initialize(directory = ".")
        @current_directory = File.expand_path(directory)
        @history = load_history
        @workflows_cache = {}
      end

      # List all available workflows in the current directory
      def list_workflows(recursive: true)
        ::CLI::UI::Frame.open("Available Workflows") do
          workflows = find_workflows(recursive: recursive)

          if workflows.empty?
            puts ::CLI::UI.fmt("{{yellow:No workflows found in #{@current_directory}}}")
            return []
          end

          # Group workflows by directory
          grouped = workflows.group_by { |w| File.dirname(w[:path]) }

          grouped.each do |dir, group_workflows|
            relative_dir = dir == @current_directory ? "." : Pathname.new(dir).relative_path_from(@current_directory).to_s

            puts ::CLI::UI.fmt("\n{{bold:#{relative_dir}/}}")

            group_workflows.each do |workflow|
              display_workflow_item(workflow)
            end
          end

          workflows
        end
      end

      # Display detailed information about a specific workflow
      def show_workflow(workflow_path)
        workflow_path = resolve_workflow_path(workflow_path)
        return unless workflow_path

        ::CLI::UI::Frame.open("Workflow Details: #{File.basename(workflow_path)}") do
          config = YAML.safe_load_file(workflow_path)

          # Basic information
          puts ::CLI::UI.fmt("{{bold:Name:}} #{config["name"] || "Unnamed"}")
          puts ::CLI::UI.fmt("{{bold:Description:}} #{config["description"] || "No description"}")
          puts ::CLI::UI.fmt("{{bold:Path:}} #{workflow_path}")

          # Model configuration
          if config["model"]
            puts ::CLI::UI.fmt("{{bold:Model:}} #{config["model"]}")
          end

          # Tools
          if config["tools"]&.any?
            puts ::CLI::UI.fmt("\n{{bold:Tools:}}")
            config["tools"].each do |tool|
              puts ::CLI::UI.fmt("  • #{tool}")
            end
          end

          # Steps
          if config["steps"]
            puts ::CLI::UI.fmt("\n{{bold:Steps:}} (#{config["steps"].size})")
            config["steps"].each_with_index do |step, index|
              step_display = format_step_for_display(step)
              puts ::CLI::UI.fmt("  {{cyan:#{index + 1}.}} #{step_display}")
            end
          end

          # Execution history
          history_entries = @history[workflow_path] || []
          if history_entries.any?
            puts ::CLI::UI.fmt("\n{{bold:Recent Executions:}}")
            history_entries.last(5).reverse.each do |entry|
              display_history_entry(entry)
            end
          else
            puts ::CLI::UI.fmt("\n{{gray:No execution history}}")
          end

          # File stats
          stat = File.stat(workflow_path)
          puts ::CLI::UI.fmt("\n{{bold:File Information:}}")
          puts ::CLI::UI.fmt("  Modified: #{stat.mtime.strftime("%Y-%m-%d %H:%M:%S")}")
          puts ::CLI::UI.fmt("  Size: #{format_file_size(stat.size)}")
        rescue => e
          puts ::CLI::UI.fmt("{{red:Error loading workflow: #{e.message}}}")
        end
      end

      # Edit a workflow with the user's preferred editor
      def edit_workflow(workflow_path)
        workflow_path = resolve_workflow_path(workflow_path)
        return unless workflow_path

        editor = ENV["EDITOR"] || ENV["VISUAL"] || detect_editor

        unless editor
          puts ::CLI::UI.fmt("{{red:No editor found. Set EDITOR environment variable.}}")
          return
        end

        puts ::CLI::UI.fmt("{{cyan:Opening #{File.basename(workflow_path)} in #{editor}...}}")

        # Store original content for comparison
        original_content = File.read(workflow_path)
        original_mtime = File.stat(workflow_path).mtime

        # Open in editor
        # Use system for editor invocation (allowed for external editor)
        success = system(editor, workflow_path)

        unless success
          puts ::CLI::UI.fmt("{{red:Failed to open editor}}")
          return
        end

        # Check if file was modified
        new_mtime = File.stat(workflow_path).mtime
        new_content = File.read(workflow_path)

        if new_mtime > original_mtime || new_content != original_content
          puts ::CLI::UI.fmt("{{green:✓}} Workflow updated")

          # Validate the updated workflow
          begin
            YAML.safe_load_file(workflow_path)
            puts ::CLI::UI.fmt("{{green:✓}} Workflow syntax is valid")

            # Clear cache for this workflow
            @workflows_cache.delete(workflow_path)

            true
          rescue => e
            puts ::CLI::UI.fmt("{{red:⚠}} Warning: Workflow has syntax errors: #{e.message}")

            if ::CLI::UI.confirm("Would you like to fix the errors?")
              edit_workflow(workflow_path)
            end

            false
          end
        else
          puts ::CLI::UI.fmt("{{gray:No changes made}}")
          false
        end
      end

      # Track workflow execution in history
      def track_execution(workflow_path, success:, duration: nil, error: nil)
        workflow_path = File.expand_path(workflow_path)

        @history[workflow_path] ||= []
        @history[workflow_path] << {
          timestamp: Time.now.iso8601,
          success: success,
          duration: duration,
          error: error&.to_s,
        }

        # Keep only last 100 executions per workflow
        @history[workflow_path] = @history[workflow_path].last(100)

        save_history
      end

      # Get execution statistics for a workflow
      def get_statistics(workflow_path)
        workflow_path = resolve_workflow_path(workflow_path)
        return unless workflow_path

        entries = @history[workflow_path] || []
        return if entries.empty?

        successful = entries.count { |e| e[:success] }
        failed = entries.count { |e| !e[:success] }

        durations = entries.filter_map { |e| e[:duration] }.compact
        avg_duration = durations.empty? ? nil : durations.sum.to_f / durations.size

        {
          total_runs: entries.size,
          successful: successful,
          failed: failed,
          success_rate: (successful.to_f / entries.size * 100).round(1),
          average_duration: avg_duration,
          last_run: entries.last[:timestamp],
          last_success: entries.reverse.find { |e| e[:success] }&.dig(:timestamp),
        }
      end

      # Hot-reload workflows in current session
      def reload_workflow(workflow_path)
        workflow_path = resolve_workflow_path(workflow_path)
        return unless workflow_path

        ::CLI::UI::Frame.open("Reloading Workflow") do
          # Clear any cached data
          @workflows_cache.delete(workflow_path)

          # Reload and validate
          config = YAML.safe_load_file(workflow_path)

          puts ::CLI::UI.fmt("{{green:✓}} Workflow reloaded successfully")
          puts ::CLI::UI.fmt("  Name: #{config["name"]}")
          puts ::CLI::UI.fmt("  Steps: #{config["steps"]&.size || 0}")
          puts ::CLI::UI.fmt("  Tools: #{config["tools"]&.size || 0}")

          true
        rescue => e
          puts ::CLI::UI.fmt("{{red:✗}} Failed to reload workflow: #{e.message}")
          false
        end
      end

      # Create a new workflow from template
      def create_from_template(template_name = nil)
        templates = {
          "basic" => {
            name: "Basic Workflow",
            description: "A simple workflow template",
            content: {
              "name" => "My Workflow",
              "description" => "Describe what this workflow does",
              "tools" => ["Roast::Tools::ReadFile"],
              "steps" => [
                "Read input files",
                "Process the data",
                "Generate output",
              ],
            },
          },
          "analysis" => {
            name: "Analysis Workflow",
            description: "Template for data analysis workflows",
            content: {
              "name" => "Data Analysis",
              "description" => "Analyze data files for insights",
              "model" => "google:gemini-2.0-flash",
              "tools" => [
                "Roast::Tools::ReadFile",
                "Roast::Tools::Grep",
                "Roast::Tools::Search",
              ],
              "steps" => [
                "Read the provided data files",
                "Identify key patterns and trends",
                "Calculate summary statistics",
                "Generate insights report",
              ],
            },
          },
          "code-review" => {
            name: "Code Review Workflow",
            description: "Template for code review and analysis",
            content: {
              "name" => "Code Review",
              "description" => "Review code for quality and best practices",
              "tools" => [
                "Roast::Tools::ReadFile",
                "Roast::Tools::Grep",
                "Roast::Tools::CodingAgent",
              ],
              "steps" => [
                "analyze_code: Review the code for potential issues",
                "check_style: Verify code style and formatting",
                "security_review: Check for security vulnerabilities",
                "suggest_improvements: Provide improvement suggestions",
              ],
            },
          },
        }

        unless template_name && templates[template_name]
          # Let user choose template
          template_name = ::CLI::UI::Prompt.ask("Choose a template:") do |handler|
            templates.each do |key, tmpl|
              handler.option(tmpl[:name]) { key }
            end
            handler.option("Cancel") { nil }
          end

          return unless template_name
        end
        template = templates[template_name]

        # Get workflow name
        name = ::CLI::UI.ask("Workflow filename (without extension):", default: template_name)
        filename = "#{name}.yml"

        # Check if file exists
        if File.exist?(filename)
          overwrite = ::CLI::UI.confirm("File '#{filename}' exists. Overwrite?")
          return unless overwrite
        end

        # Write template
        File.write(filename, YAML.dump(template[:content]))
        puts ::CLI::UI.fmt("{{green:✓}} Created workflow: #{filename}")

        # Ask if user wants to edit
        if ::CLI::UI.confirm("Edit the workflow now?")
          edit_workflow(filename)
        end

        filename
      end

      private

      def find_workflows(recursive: true)
        pattern = recursive ? "**/workflow*.{yml,yaml}" : "workflow*.{yml,yaml}"

        Dir.glob(File.join(@current_directory, pattern)).map do |path|
          next unless File.file?(path)

          # Try to load cached or fresh workflow info
          @workflows_cache[path] ||= load_workflow_info(path)
        end.compact.sort_by { |w| w[:name] }
      end

      def load_workflow_info(path)
        config = YAML.safe_load_file(path)

        {
          path: path,
          name: config["name"] || File.basename(path, ".*"),
          description: config["description"],
          steps_count: config["steps"]&.size || 0,
          tools_count: config["tools"]&.size || 0,
          last_run: @history[path]&.last&.dig(:timestamp),
          last_success: @history[path]&.reverse&.find { |e| e[:success] }&.dig(:timestamp),
        }
      rescue => e
        {
          path: path,
          name: File.basename(path, ".*"),
          description: "Error loading workflow: #{e.message}",
          error: true,
        }
      end

      def display_workflow_item(workflow)
        status = if workflow[:error]
          "{{red:✗}}"
        elsif workflow[:last_success]
          "{{green:✓}}"
        elsif workflow[:last_run]
          "{{yellow:!}}"
        else
          "{{gray:○}}"
        end

        name = workflow[:name]
        name = "{{bold:#{name}}}" if workflow[:last_run]

        info_parts = []
        info_parts << "#{workflow[:steps_count]} steps" if workflow[:steps_count]&.positive?
        info_parts << "#{workflow[:tools_count]} tools" if workflow[:tools_count]&.positive?

        if workflow[:last_run]
          last_run_relative = format_time_relative(workflow[:last_run])
          info_parts << "last: #{last_run_relative}"
        end

        info = info_parts.any? ? " {{gray:(#{info_parts.join(", ")})}}" : ""

        puts ::CLI::UI.fmt("  #{status} #{name}#{info}")

        if workflow[:description] && !workflow[:error]
          puts ::CLI::UI.fmt("      {{gray:#{workflow[:description]}}}")
        end
      end

      def display_history_entry(entry)
        Time.parse(entry[:timestamp])
        relative_time = format_time_relative(entry[:timestamp])

        status = entry[:success] ? "{{green:✓}}" : "{{red:✗}}"

        duration_str = entry[:duration] ? " (#{format_duration(entry[:duration])})" : ""
        error_str = entry[:error] ? " - #{entry[:error]}" : ""

        puts ::CLI::UI.fmt("  #{status} #{relative_time}#{duration_str}#{error_str}")
      end

      def format_step_for_display(step)
        case step
        when String
          step.length > 60 ? "#{step[0..57]}..." : step
        when Hash
          key = step.keys.first
          "#{key}: ..."
        else
          step.to_s
        end
      end

      def format_time_relative(timestamp_str)
        timestamp = Time.parse(timestamp_str)
        diff = Time.now - timestamp

        case diff
        when 0..59
          "#{diff.round}s ago"
        when 60..3599
          "#{(diff / 60).round}m ago"
        when 3600..86399
          "#{(diff / 3600).round}h ago"
        when 86400..604799
          "#{(diff / 86400).round}d ago"
        else
          timestamp.strftime("%Y-%m-%d")
        end
      end

      def format_duration(seconds)
        return "0s" unless seconds

        if seconds < 60
          "#{seconds.round(1)}s"
        elsif seconds < 3600
          minutes = (seconds / 60).floor
          secs = (seconds % 60).round
          "#{minutes}m #{secs}s"
        else
          hours = (seconds / 3600).floor
          minutes = ((seconds % 3600) / 60).floor
          "#{hours}h #{minutes}m"
        end
      end

      def format_file_size(bytes)
        units = ["B", "KB", "MB", "GB"]
        size = bytes.to_f
        unit = 0

        while size >= 1024 && unit < units.size - 1
          size /= 1024.0
          unit += 1
        end

        "#{size.round(1)} #{units[unit]}"
      end

      def resolve_workflow_path(path)
        return unless path

        # Try exact path first
        return path if File.exist?(path)

        # Try with .yml extension
        yml_path = "#{path}.yml"
        return yml_path if File.exist?(yml_path)

        # Try with .yaml extension
        yaml_path = "#{path}.yaml"
        return yaml_path if File.exist?(yaml_path)

        # Try in current directory
        local_path = File.join(@current_directory, path)
        return local_path if File.exist?(local_path)

        # Try with extensions in current directory
        yml_local = File.join(@current_directory, "#{path}.yml")
        return yml_local if File.exist?(yml_local)

        yaml_local = File.join(@current_directory, "#{path}.yaml")
        return yaml_local if File.exist?(yaml_local)

        puts ::CLI::UI.fmt("{{red:Workflow not found: #{path}}}")
        nil
      end

      def detect_editor
        # Check for available editors using which command
        ["code", "vim", "vi", "nano", "emacs"].find do |editor|
          system("which #{editor} > /dev/null 2>&1")
        end
      end

      def load_history
        return {} unless File.exist?(HISTORY_FILE)

        JSON.parse(File.read(HISTORY_FILE))
      rescue => e
        puts ::CLI::UI.fmt("{{yellow:Warning: Could not load history: #{e.message}}}")
        {}
      end

      def save_history
        File.write(HISTORY_FILE, JSON.pretty_generate(@history))
      rescue => e
        puts ::CLI::UI.fmt("{{yellow:Warning: Could not save history: #{e.message}}}")
      end
    end
  end
end
