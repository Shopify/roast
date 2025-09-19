# typed: true
# frozen_string_literal: true

require 'pathname'

module Roast
  module TUI
    class Application
      attr_reader :llm_client, :session_manager, :display, :command_handler, :config
      
      def initialize(config = nil)
        # Enable StdoutRouter for CLI::UI to work properly
        ::CLI::UI::StdoutRouter.enable
        
        @config = config || TUI.configure
        @running = false
        @interrupted_once = false
        @session_manager = SessionManager.new
        
        begin
          @display = Display.new
        rescue => e
          puts "[DEBUG] Error creating Display: #{e.class} - #{e.message}"
          raise
        end
        
        @command_handler = CommandHandler.new(self)
        
        initialize_llm_client
        setup_signal_handlers
      end
      
      def start
        @running = true
        
        ::CLI::UI::Frame.open("Roast TUI v#{TUI::VERSION}", color: :cyan) do
          @display.show_welcome
          @display.show_model_info(@llm_client.model)
          ::CLI::UI::Frame.divider("")
          
          main_loop
        end
      rescue Interrupt
        shutdown
      ensure
        cleanup
      end
      
      def stop
        @running = false
      end
      
      def switch_model(new_model)
        @config.model = new_model
        initialize_llm_client
        @display.show_success("Switched to model: #{new_model}")
      end
      
      def switch_agent(agent_name)
        # Agent switching logic - can be extended
        @session_manager.metadata[:agent] = agent_name
        @display.show_success("Switched to agent: #{agent_name}")
      end
      
      def clear_conversation
        @session_manager.clear
        @display.show_success("Conversation cleared")
      end
      
      def export_session(filename = nil)
        filename ||= generate_session_filename
        path = File.expand_path(filename)
        @session_manager.save_to_file(path)
        @display.show_success("Session exported to: #{path}")
        path
      rescue => e
        @display.show_error("Failed to export session: #{e.message}")
        nil
      end
      
      private
      
      def initialize_llm_client
        @llm_client = LLMClient.new(
          api_key: @config.api_key,
          base_url: @config.base_url,
          model: @config.model,
          tool_registry: create_tool_registry
        )
      end
      
      def create_tool_registry
        registry = ToolRegistry.new
        
        # Add custom TUI tools
        registry.register(
          name: "create_workflow",
          description: "Create a new Roast workflow from a description",
          parameters: {
            type: "object",
            properties: {
              description: {
                type: "string",
                description: "Description of the workflow to create"
              },
              name: {
                type: "string",
                description: "Name for the workflow"
              }
            },
            required: ["description", "name"]
          }
        ) do |args|
          create_workflow_from_description(args["description"], args["name"])
        end
        
        registry
      end
      
      def setup_signal_handlers
        trap("INT") { shutdown }
        trap("TERM") { shutdown }
      end
      
      def main_loop
        while @running
          begin
            input = get_user_input
            next if input.nil? || input.empty?
            
            if input.start_with?("/")
              handle_command(input)
            else
              handle_message(input)
            end
          rescue => e
            @display.show_error("Error: #{e.message}")
            @display.show_debug(e.backtrace.join("\n")) if ENV["DEBUG"]
          end
        end
      end
      
      def get_user_input
        begin
          # Use custom input with tab completion
          get_input_with_completion
        rescue ArgumentError => e
          puts "[DEBUG] ArgumentError in get_user_input: #{e.message}"
          puts "[DEBUG] Backtrace:"
          e.backtrace.first(5).each { |line| puts "  #{line}" }
          raise
        end
      end
      
      def get_input_with_completion
        begin
          require 'reline'
          
          # Configure Reline for better completion display
          Reline.completion_append_character = ""
          
          # Set up tab completion for Reline
          setup_tab_completion
          
          # Use a simple prompt for Reline
          prompt = "You: "
          
          begin
            input = Reline.readline(prompt, true) # true = add to history
          rescue Interrupt
            # Handle Ctrl-C - first time clears line, second time exits
            if @interrupted_once
              puts "\nGoodbye!"  # New line after Ctrl-C
              shutdown
              return nil
            else
              @interrupted_once = true
              puts "^C"  # Show that Ctrl-C was pressed
              return ""  # Return empty to continue loop
            end
          end
          
          # Handle Ctrl-D (EOF) - Reline returns nil
          if input.nil?
            puts "\nGoodbye!"  # New line after Ctrl-D
            shutdown
            return nil
          end
          
          input
        rescue LoadError
          # Fallback to CLI::UI if Reline isn't available
          input = ::CLI::UI::Prompt.ask("You")
        end
        
        # Reset interrupt flag on successful input
        @interrupted_once = false if input && !input.strip.empty?
        
        input&.strip
      end
      
      def setup_tab_completion
        # Get available commands for completion
        commands = @command_handler.available_commands
        
        # Define workflow subcommands
        workflow_subcommands = ["create", "run", "list"]
        
        # Define the completion proc
        completion_proc = proc do |input|
          # Debug output if DEBUG environment variable is set
          if ENV["DEBUG"]
            puts "[DEBUG] Tab completion input: #{input.inspect}"
          end
          
          # Reline passes only the current word being completed, not the full line
          # We need to get the full line from Reline.line_buffer
          full_input = Reline.line_buffer rescue input
          
          if ENV["DEBUG"] && full_input != input
            puts "[DEBUG] Full line buffer: #{full_input.inspect}"
          end
          
          # Handle slash command completion
          if full_input.start_with?("/")
            # Complete slash commands
            cmd_part = full_input[1..-1]
            
            if cmd_part.include?(" ")
              # Command with arguments - check for file completion
              parts = full_input.split(" ", 2)
              command = parts[0][1..-1]
              arg_part = parts[1] || ""
              
              # For commands that take file paths, do file completion
              if ["run"].include?(command)
                # Complete only YAML files for workflow run
                complete_file_path(input, extensions: ['.yml', '.yaml']).map { |f| f }
              elsif ["load", "export", "save"].include?(command)
                # Complete any files
                complete_file_path(input).map { |f| f }
              elsif command == "workflow"
                # Handle workflow subcommands
                if arg_part.include?(" ")
                  # Workflow subcommand with args (e.g., "workflow run <file>")
                  sub_parts = arg_part.split(" ", 2)
                  subcommand = sub_parts[0]
                  sub_arg = sub_parts[1] || ""
                  
                  if subcommand == "run"
                    # Complete YAML files for workflow run
                    complete_file_path(input, extensions: ['.yml', '.yaml']).map { |f| f }
                  elsif subcommand == "create"
                    # No file completion for create
                    []
                  else
                    []
                  end
                else
                  # Complete workflow subcommands - input is just the partial subcommand
                  results = workflow_subcommands.select { |sub| sub.start_with?(input) }.map { |sub| sub }
                  if ENV["DEBUG"]
                    puts "[DEBUG] Workflow subcommand results for '#{input}': #{results.inspect}"
                  end
                  results
                end
              else
                []
              end
            else
              # Just the command part - check for exact matches that need subcommands
              matching_commands = commands.select { |cmd| cmd.start_with?(cmd_part) }
              
              if matching_commands.size == 1 && matching_commands[0] == cmd_part
                # Exact match for a command that might have subcommands
                if cmd_part == "workflow"
                  # User typed "/workflow" exactly, show subcommands
                  results = workflow_subcommands.map { |sub| "/workflow #{sub}" }
                  if ENV["DEBUG"]
                    puts "[DEBUG] Showing workflow subcommands: #{results.inspect}"
                  end
                  results
                else
                  # Single exact match with no subcommands, return it
                  ["/#{cmd_part}"]
                end
              else
                # Partial command or multiple matches, complete them
                results = matching_commands.map { |cmd| "/#{cmd}" }
                if ENV["DEBUG"]
                  puts "[DEBUG] Completion results: #{results.inspect}"
                end
                results
              end
            end
          else
            # Regular text, no completion
            []
          end
        end
        
        # Set up Reline completion (we know Reline is loaded at this point)
        Reline.completion_proc = completion_proc
      end
      
      def complete_file_path(partial_path, extensions: nil)
        # Handle empty partial_path differently - list current directory
        if partial_path.nil? || (partial_path.is_a?(String) && partial_path.strip.empty?)
          partial_path = ""
        end
        
        # Figure out what directory to search and what to match
        if partial_path.empty?
          # List current directory
          dir = "."
          partial = ""
          prefix = ""
        elsif partial_path.end_with?("/")
          # Directory with trailing slash - list its contents
          dir = partial_path
          partial = ""
          prefix = partial_path
        else
          # Get directory and basename
          dir = File.dirname(partial_path)
          partial = File.basename(partial_path)
          # Keep the directory prefix for the results
          if dir == "."
            prefix = ""
          else
            prefix = "#{dir}/"
          end
        end
        
        # Get matching files and directories
        search_pattern = File.join(dir, "#{partial}*")
        matches = Dir.glob(search_pattern, File::FNM_DOTMATCH).select do |path|
          # Filter out . and ..
          basename = File.basename(path)
          next false if basename == "." || basename == ".."
          
          # If extensions filter is provided, apply it to files (not directories)
          if extensions && !File.directory?(path)
            ext = File.extname(path).downcase
            next false unless extensions.include?(ext)
          end
          
          true
        end
        
        # Format the matches - return the completion with the right prefix
        matches.map do |full_path|
          # Get just the basename for the completion
          basename = File.basename(full_path)
          
          # Add trailing slash for directories
          if File.directory?(full_path)
            basename = basename.end_with?("/") ? basename : "#{basename}/"
          end
          
          # Return with the original prefix for Reline to work correctly
          "#{prefix}#{basename}"
        end.sort
      end
      
      def handle_command(input)
        command, *args = input[1..-1].split(/\s+/)
        @command_handler.handle(command, args)
      end
      
      def handle_message(input)
        @session_manager.add_user_message(input)
        
        ::CLI::UI::Frame.open("Assistant", color: :green, timing: true) do
          messages = @session_manager.get_context_messages(
            max_tokens: @config.max_context_tokens,
            model: @llm_client.model
          )
          
          # Stream the response without spinner
          accumulated_content = ""
          first_chunk = true
          
          @llm_client.stream_with_tools(messages) do |event|
            case event[:type]
            when :chunk
              chunk = event[:data]
              if chunk.dig("choices", 0, "delta", "content")
                content = chunk["choices"][0]["delta"]["content"]
                accumulated_content += content
                
                # Print the content as it streams
                if first_chunk
                  first_chunk = false
                  # Just start printing the content
                end
                print content
                $stdout.flush
              end
            when :tool_start
              # Clear any partial content line and start fresh
              puts "" if accumulated_content && !accumulated_content.empty?
              @display.show_tool_execution(event[:name], event[:arguments])
            when :tool_complete
              @display.show_tool_result(event[:name], event[:result])
              # Resume content on a new line after tool
              first_chunk = true
            when :tool_error
              @display.show_error("Tool error: #{event[:error]}")
            end
          end
          
          # Ensure we end with a newline if we printed content
          puts if accumulated_content && !accumulated_content.empty?
          
          # Add assistant's response to session
          @session_manager.add_assistant_message(accumulated_content) if accumulated_content && !accumulated_content.empty?
          
          # Auto-save session if configured
          auto_save_session if @config.auto_save_sessions
        end
      end
      
      def create_workflow_from_description(description, name)
        # Integration with Roast workflow generator
        workflow_dir = File.join(Dir.pwd, "roast", name)
        FileUtils.mkdir_p(workflow_dir)
        
        workflow_content = generate_workflow_yaml(description, name)
        workflow_path = File.join(workflow_dir, "workflow.yml")
        
        File.write(workflow_path, workflow_content)
        
        @display.show_success("Workflow created at: #{workflow_path}")
        workflow_path
      end
      
      def generate_workflow_yaml(description, name)
        # Basic workflow template - can be enhanced with AI generation
        <<~YAML
          name: "#{name}"
          description: "#{description}"
          model: "gpt-4-turbo-preview"
          
          steps:
            - analyze: |
                Analyze the following requirement and provide a solution:
                #{description}
          
          analyze:
            print_response: true
        YAML
      end
      
      def auto_save_session
        return unless @session_manager.messages.any?
        
        session_dir = @config.session_directory
        FileUtils.mkdir_p(session_dir)
        
        filename = File.join(session_dir, "autosave_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
        @session_manager.save_to_file(filename)
      rescue => e
        # Silent fail for auto-save
        warn "Auto-save failed: #{e.message}" if ENV["DEBUG"]
      end
      
      def generate_session_filename
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        "roast_session_#{timestamp}.json"
      end
      
      def shutdown
        puts "\n"
        @display.show_info("Shutting down...")
        @running = false
        cleanup
        # Exit immediately instead of waiting for the loop
        exit(0)
      end
      
      def cleanup
        # Save session before exit
        if @config.auto_save_sessions && @session_manager.messages.any?
          auto_save_session
          @display.show_info("Session auto-saved")
        end
      end
    end
  end
end
