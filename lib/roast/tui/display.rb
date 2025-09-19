# typed: true
# frozen_string_literal: true

module Roast
  module TUI
    class Display
      COLORS = {
        user: :cyan,
        assistant: :green,
        system: :yellow,
        tool: :magenta,
        error: :red,
        success: :green,
        info: :blue,
        debug: :gray
      }.freeze
      
      def initialize
        @rouge_available = begin
          require "rouge"
          true
        rescue LoadError
          false
        end
        @code_formatter = @rouge_available ? Rouge::Formatters::Terminal256.new(theme: 'monokai') : nil
      end
      
      def show_welcome
        puts ::CLI::UI.fmt("{{bold:Welcome to Roast TUI}} {{v}}")
        puts ::CLI::UI.fmt("Type {{info:/help}} for available commands")
        puts
      end
      
      def show_model_info(model)
        puts ::CLI::UI.fmt("Model: {{info:#{model}}}")
      end
      
      def show_message(role, content, timestamp: nil)
        color = COLORS[role.to_sym] || :default
        
        ::CLI::UI::Frame.open(role.capitalize, color: color) do
          if timestamp
            puts ::CLI::UI.fmt("{{gray:#{timestamp.strftime('%H:%M:%S')}}}")
          end
          
          render_content(content)
        end
      end
      
      def show_tool_execution(tool_name, arguments)
        ::CLI::UI::Frame.open("Tool: #{tool_name}", color: :yellow) do
          puts ::CLI::UI.fmt("{{bold:Executing:}} #{tool_name}")
          
          if arguments && !arguments.empty?
            puts ::CLI::UI.fmt("{{bold:Parameters:}}")
            arguments.each do |key, value|
              formatted_value = format_parameter_value(value)
              puts ::CLI::UI.fmt("  {{info:#{key}}}: #{formatted_value}")
            end
          end
        end
      end
      
      def show_tool_result(tool_name, result)
        # Compact display for tool results
        if result.is_a?(String) && result.length > 200
          truncated = result[0..200] + "..."
          puts ::CLI::UI.fmt("{{success:✓}} #{tool_name} completed (#{result.length} chars)")
        else
          puts ::CLI::UI.fmt("{{success:✓}} #{tool_name} completed")
        end
      end
      
      def show_parallel_tools(tool_calls)
        ::CLI::UI::SpinGroup.new do |group|
          tool_calls.each do |tool_call|
            tool_name = tool_call[:function][:name]
            
            group.add("Executing #{tool_name}...") do |spinner|
              yield(tool_call, spinner) if block_given?
            end
          end
        end
      end
      
      def show_error(message)
        ::CLI::UI::Frame.open("Error", color: :red, failure_text: "✗") do
          puts ::CLI::UI.fmt("{{red:#{message}}}")
        end
      end
      
      def show_success(message)
        puts ::CLI::UI.fmt("{{success:✓}} {{green:#{message}}}")
      end
      
      def show_info(message)
        puts ::CLI::UI.fmt("{{info:ℹ}} {{blue:#{message}}}")
      end
      
      def show_debug(message)
        return unless ENV["DEBUG"]
        puts ::CLI::UI.fmt("{{gray:[DEBUG] #{message}}}")
      end
      
      def show_workflow_list(workflows)
        ::CLI::UI::Frame.open("Available Workflows", color: :cyan) do
          if workflows.empty?
            puts "No workflows found"
          else
            workflows.each do |workflow|
              puts ::CLI::UI.fmt("• {{bold:#{workflow[:name]}}}")
              puts ::CLI::UI.fmt("  {{gray:#{workflow[:path]}}}")
              puts ::CLI::UI.fmt("  {{gray:#{workflow[:description]}}") if workflow[:description]
            end
          end
        end
      end
      
      def show_help(commands)
        ::CLI::UI::Frame.open("Available Commands", color: :cyan) do
          puts ::CLI::UI.fmt("{{bold:Slash Commands:}}")
          puts
          
          commands.each do |cmd, info|
            puts ::CLI::UI.fmt("{{info:/#{cmd}}} - #{info[:description]}")
            if info[:usage]
              puts ::CLI::UI.fmt("  {{gray:Usage: /#{cmd} #{info[:usage]}}}")
            end
          end
          
          puts
          puts ::CLI::UI.fmt("{{bold:Tips:}}")
          puts ::CLI::UI.fmt("• Type normally to chat with the AI assistant")
          puts ::CLI::UI.fmt("• Press Ctrl+C to exit")
          puts ::CLI::UI.fmt("• Set DEBUG=1 for verbose output")
        end
      end
      
      def render_markdown(content)
        # Basic markdown rendering with CLI-UI formatting
        lines = content.split("\n")
        in_code_block = false
        code_language = nil
        code_buffer = []
        
        lines.each do |line|
          if line.match(/^```(\w*)/)
            if in_code_block
              # End code block
              render_code_block(code_buffer.join("\n"), code_language)
              code_buffer.clear
              in_code_block = false
              code_language = nil
            else
              # Start code block
              in_code_block = true
              code_language = $1.empty? ? nil : $1
            end
          elsif in_code_block
            code_buffer << line
          else
            render_markdown_line(line)
          end
        end
        
        # Handle unclosed code block
        if in_code_block && code_buffer.any?
          render_code_block(code_buffer.join("\n"), code_language)
        end
      end
      
      private
      
      def render_content(content)
        # Check if content looks like markdown
        if content.include?("```") || content.include?("**") || content.include?("##")
          render_markdown(content)
        else
          puts content
        end
      end
      
      def render_markdown_line(line)
        # Headers
        line = line.gsub(/^### (.+)$/, '{{bold:\1}}')
        line = line.gsub(/^## (.+)$/, '{{bold:{{cyan:\1}}}}')
        line = line.gsub(/^# (.+)$/, '{{bold:{{blue:\1}}}}')
        
        # Bold
        line = line.gsub(/\*\*(.+?)\*\*/, '{{bold:\1}}')
        
        # Italic  
        line = line.gsub(/\*(.+?)\*/, '{{italic:\1}}')
        
        # Inline code
        line = line.gsub(/`(.+?)`/, '{{cyan:\1}}')
        
        # Links
        line = line.gsub(/\[(.+?)\]\((.+?)\)/, '{{underline:\1}} ({{gray:\2}})')
        
        # Lists
        line = line.gsub(/^(\s*)[*-] (.+)$/, '\1• \2')
        line = line.gsub(/^(\s*)\d+\. (.+)$/, '\1\2')
        
        puts ::CLI::UI.fmt(line)
      end
      
      def render_code_block(code, language)
        ::CLI::UI::Frame.open("Code", color: :cyan) do
          if language
            puts ::CLI::UI.fmt("{{gray:Language: #{language}}}")
          end
          
          begin
            if @rouge_available && language && Rouge::Lexer.find(language)
              lexer = Rouge::Lexer.find(language).new
              tokens = lexer.lex(code)
              formatted = @code_formatter.format(tokens)
              puts formatted
            else
              puts code
            end
          rescue => e
            # Fallback to plain text if Rouge fails
            show_debug("Code highlighting failed: #{e.message}")
            puts code
          end
        end
      end
      
      def format_parameter_value(value)
        case value
        when String
          value.length > 50 ? "#{value[0..50]}..." : value
        when Hash, Array
          JSON.pretty_generate(value)[0..100] + "..."
        else
          value.to_s
        end
      rescue
        value.inspect
      end
    end
  end
end