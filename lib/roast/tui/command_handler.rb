# typed: true
# frozen_string_literal: true

require 'stringio'

module Roast
  module TUI
    class CommandHandler
      COMMANDS = {
        "help" => {
          description: "Show available commands",
          handler: :handle_help
        },
        "clear" => {
          description: "Clear conversation history",
          handler: :handle_clear
        },
        "exit" => {
          description: "Exit the TUI",
          handler: :handle_exit
        },
        "quit" => {
          description: "Exit the TUI",
          handler: :handle_exit
        },
        "export" => {
          description: "Export current session",
          usage: "[filename]",
          handler: :handle_export
        },
        "model" => {
          description: "Switch AI model",
          usage: "<model_name>",
          handler: :handle_model
        },
        "workflow" => {
          description: "Workflow management",
          usage: "create|run|list [args...]",
          handler: :handle_workflow
        },
        "run" => {
          description: "Run a workflow file",
          usage: "<workflow_file>",
          handler: :handle_run
        },
        "agent" => {
          description: "Agent management",
          usage: "switch <agent_name>",
          handler: :handle_agent
        },
        "status" => {
          description: "Show session status",
          handler: :handle_status
        },
        "save" => {
          description: "Save current session",
          usage: "[filename]",
          handler: :handle_save
        },
        "load" => {
          description: "Load a session",
          usage: "<filename>",
          handler: :handle_load
        },
        "history" => {
          description: "Show conversation history",
          usage: "[count]",
          handler: :handle_history
        }
      }.freeze
      
      def initialize(application)
        @application = application
        @display = application.display
      end
      
      def available_commands
        COMMANDS.keys
      end
      
      def handle(command, args = [])
        # Clean up the command in case it has extra characters
        command = command.to_s.strip
        
        # Check if command is empty or looks like a file path
        if command.empty?
          @display.show_info("Type /help to see available commands")
          return
        elsif command.include?('/') && command.include?('.')
          @display.show_error("That looks like a file path, not a command")
          @display.show_info("Did you mean to type a message instead of a command?")
          @display.show_info("Commands start with /, like /help")
          return
        end
        
        command_info = COMMANDS[command.downcase]
        
        if command_info
          send(command_info[:handler], args)
        else
          @display.show_error("Unknown command: /#{command}")
          @display.show_info("Type /help for available commands")
        end
      rescue => e
        @display.show_error("Command failed: #{e.message}")
        @display.show_debug(e.backtrace.join("\n")) if ENV["DEBUG"]
      end
      
      private
      
      def handle_help(_args)
        @display.show_help(COMMANDS)
      end
      
      def handle_clear(_args)
        @application.clear_conversation
      end
      
      def handle_exit(_args)
        @display.show_info("Goodbye!")
        @application.stop
      end
      
      def handle_export(args)
        filename = args.first
        exported_path = @application.export_session(filename)
        
        if exported_path && args.include?("--open")
          system("open", exported_path)
        end
      end
      
      def handle_model(args)
        if args.empty?
          current_model = @application.llm_client.model
          @display.show_info("Current model: #{current_model}")
          @display.show_info("Available models: gpt-4-turbo-preview, gpt-4, gpt-3.5-turbo")
        else
          new_model = args.join(" ")
          @application.switch_model(new_model)
        end
      end
      
      def handle_workflow(args)
        subcommand = args.shift
        
        case subcommand
        when "create"
          handle_workflow_create(args)
        when "run"
          handle_workflow_run(args)
        when "list"
          handle_workflow_list(args)
        else
          @display.show_error("Unknown workflow command: #{subcommand}")
          @display.show_info("Usage: /workflow create|run|list")
        end
      end
      
      def handle_workflow_create(args)
        name = nil
        description = nil
        
        if args.empty?
          # Interactive mode
          name = prompt_for_input("Workflow name")
          description = prompt_for_input("Workflow description")
        else
          name = args.shift
          description = args.join(" ")
        end
        
        if name.nil? || name.empty?
          @display.show_error("Workflow name is required")
          return
        end
        
        # Ensure roast directory exists
        roast_dir = File.join(Dir.pwd, "roast")
        FileUtils.mkdir_p(roast_dir)
        
        # Create workflow directory with sanitized name
        sanitized_name = name.downcase.gsub(/\s+/, "_")
        workflow_dir = File.join(roast_dir, sanitized_name)
        FileUtils.mkdir_p(workflow_dir)
        workflow_path = File.join(workflow_dir, "workflow.yml")
        
        ::CLI::UI::Frame.open("Creating Workflow", color: :cyan) do
          # Build a comprehensive prompt for the LLM to generate the workflow
          prompt = <<~PROMPT
            Create a Roast workflow configuration file for the following:
            Name: #{name}
            Description: #{description || "General purpose workflow"}
            
            Save the workflow to: #{workflow_path}
            
            CRITICAL Roast Workflow Knowledge:
            
            1. AVAILABLE TOOLS (use ONLY these class names - they are Ruby classes):
               - Roast::Tools::ReadFile - Read file contents
               - Roast::Tools::WriteFile - Write content to files  
               - Roast::Tools::Grep - Search for patterns in files
               - Roast::Tools::SearchFile - Search within specific files
               - Roast::Tools::Bash - Execute bash commands
               - Roast::Tools::Cmd - Execute restricted commands
               - Roast::Tools::UpdateFiles - Update multiple files
               - Roast::Tools::ApplyDiff - Apply diff patches
               - Roast::Tools::AskUser - Interactive user prompts
               - Roast::Tools::CodingAgent - Claude Code integration
               
               DO NOT use tools that don't exist like ContextSummarizer!
            
            2. STEP DEFINITION - EVERY STEP MUST HAVE A PROMPT:
               Steps can be defined in these ways:
               
               a) Inline prompt with pipe for multiline:
               ```yaml
               steps:
                 - analyze_code: |
                     Analyze the codebase and identify key patterns.
                     Focus on architecture and design.
               ```
               
               b) Simple inline string:
               ```yaml
               steps:
                 - "Search for all Ruby files and list them"
               ```
               
               c) Step name that references a prompt file (only if prompt file exists):
               ```yaml
               steps:
                 - existing_step_name  # ONLY if existing_step_name/prompt.md exists
               ```
               
               NEVER use just a step name without either an inline prompt or existing prompt file!
            
            3. CORRECT WORKFLOW STRUCTURE:
               ```yaml
               name: "#{name}"
               description: "#{description}"
               model: "#{@application.llm_client.model}"
               tools:
                 - Roast::Tools::ToolName  # Array of tool class names
               steps:
                 - step_label: |
                     The actual prompt text that tells the LLM what to do.
                     This is REQUIRED for every step!
                 - another_step: |
                     Another prompt with clear instructions.
               
               # Step configurations go at TOP LEVEL (optional):
               step_label:
                 print_response: true
               another_step:
                 print_response: false
               ```
            
            4. IMPORTANT RULES:
               - EVERY step MUST have prompt text (inline or from file)
               - Tools are capabilities available to the LLM, NOT explicitly called in steps
               - Steps describe WHAT to do in natural language
               - Step configuration is OPTIONAL and goes at top level
               - Use ONLY the tools listed above that actually exist
               - The last step should usually have print_response: true
            
            5. EXAMPLE WORKFLOW:
               ```yaml
               name: "Example"
               description: "Analyze Ruby code"
               model: "claude-opus-4-1"
               tools:
                 - Roast::Tools::Bash
                 - Roast::Tools::ReadFile
                 - Roast::Tools::Grep
               
               steps:
                 - find_files: |
                     Use bash to find all Ruby files in the current directory.
                     List the files found.
                 - analyze: |
                     Read and analyze the Ruby files to understand the codebase.
                 - summarize: |
                     Provide a summary of what you learned.
               
               find_files:
                 print_response: false
               analyze:  
                 print_response: false
               summarize:
                 print_response: true
               ```
            
            Generate a complete, valid workflow with inline prompts for ALL steps.
          PROMPT
          
          @application.session_manager.add_user_message(prompt)
          
          messages = @application.session_manager.get_context_messages(
            max_tokens: @application.config.max_context_tokens,
            model: @application.llm_client.model
          )
          
          begin
            # Set up tool registry for file writing
            tool_registry = Roast::TUI::ToolRegistry.new
            
            # Register write_file tool
            tool_registry.register(
              name: "write_file",
              description: "Write content to a file",
              parameters: {
                type: "object",
                properties: {
                  path: {
                    type: "string",
                    description: "Path to the file to write"
                  },
                  content: {
                    type: "string", 
                    description: "Content to write to the file"
                  }
                },
                required: ["path", "content"]
              }
            ) do |args|
              File.write(args["path"], args["content"])
              "File written successfully to #{args["path"]}"
            end
            
            # Create a new LLM client with the tool registry
            llm_with_tools = Roast::TUI::LLMClient.new(
              api_key: @application.config.api_key,
              base_url: @application.config.base_url,
              model: @application.config.model,
              tool_registry: tool_registry
            )
            
            # Execute with tool calling
            response = llm_with_tools.chat_with_tools(messages, max_iterations: 3)
            
            if File.exist?(workflow_path)
              @display.show_success("Workflow created: #{workflow_path}")
              @display.show_info("Run it with: /workflow run #{sanitized_name}")
              @display.show_info("Or run directly: /run #{workflow_path}")
            else
              @display.show_error("Failed to create workflow file")
              @display.show_info("Using fallback template generation...")
              
              # Fallback to basic template
              workflow_content = generate_basic_workflow(name, description)
              File.write(workflow_path, workflow_content)
              
              @display.show_success("Workflow created with template: #{workflow_path}")
              @display.show_info("Edit the workflow file to customize it further")
            end
            
            @application.session_manager.add_assistant_message(response.content) if response
          rescue => e
            @display.show_error("Error creating workflow: #{e.message}")
            @display.show_debug(e.backtrace.join("\n")) if ENV["DEBUG"]
            
            # Fallback to template
            @display.show_info("Using fallback template generation...")
            workflow_content = generate_basic_workflow(name, description)
            File.write(workflow_path, workflow_content)
            @display.show_success("Workflow created with template: #{workflow_path}")
          end
        end
      rescue => e
        @display.show_error("Error creating workflow: #{e.message}")
        @display.show_debug(e.backtrace.join("\n")) if ENV["DEBUG"]
      end
      
      def generate_basic_workflow(name, description)
        # Generate a basic workflow template based on the description
        step_prompt = nil
        tools_needed = []
        
        # Analyze the description to determine what steps and tools to include
        desc_lower = description.to_s.downcase
        
        if desc_lower.include?("ruby") || desc_lower.include?(".rb") || desc_lower.include?("file")
          step_prompt = "Analyze all Ruby files in the current directory and subdirectories.\n      #{description}"
          tools_needed = ["Roast::Tools::ReadFile", "Roast::Tools::Grep", "Roast::Tools::SearchFile"]
        elsif desc_lower.include?("test")
          step_prompt = "Execute the test suite and report results.\n      #{description}"
          tools_needed = ["Roast::Tools::Bash", "Roast::Tools::ReadFile"]
        elsif desc_lower.include?("write") || desc_lower.include?("create") || desc_lower.include?("generate")
          step_prompt = description
          tools_needed = ["Roast::Tools::WriteFile", "Roast::Tools::ReadFile"]
        elsif desc_lower.include?("summary") || desc_lower.include?("analyze")
          step_prompt = "Analyze the codebase and provide insights.\n      #{description}"
          tools_needed = ["Roast::Tools::ReadFile", "Roast::Tools::Grep"]
        else
          step_prompt = description
          tools_needed = ["Roast::Tools::Bash"]
        end
        
        # Build the workflow YAML using proper Roast format
        <<~YAML
          name: "#{name}"
          description: "#{description || 'Automated workflow'}"
          model: "#{@application.llm_client.model}"
          tools:
          #{tools_needed.map { |t| "  - #{t}" }.join("\n")}
          
          steps:
            - analyze: |
                #{step_prompt}
          
          # Step configuration
          analyze:
            print_response: true
        YAML
      end
      
      def handle_run(args)
        # Shorthand for /workflow run
        handle_workflow_run(args)
      end
      
      def handle_workflow_run(args)
        workflow_name = args.shift
        
        if workflow_name.nil? || workflow_name.empty?
          @display.show_error("Workflow name or path is required")
          @display.show_info("Usage: /workflow run <workflow_name_or_path>")
          @display.show_info("Examples:")
          @display.show_info("  /workflow run my_workflow")
          @display.show_info("  /workflow run path/to/workflow.yml")
          @display.show_info("  /workflow run ./workflow.yml")
          return
        end
        
        # Support multiple path formats
        workflow_path = if workflow_name.include?(".yml") || workflow_name.include?(".yaml")
          # Direct file path
          File.expand_path(workflow_name)
        elsif workflow_name.start_with?("./") || workflow_name.start_with?("/")
          # Explicit path
          File.expand_path(workflow_name)
        else
          # Assume it's a workflow name in the roast directory
          File.expand_path("roast/#{workflow_name}/workflow.yml")
        end
        
        unless File.exist?(workflow_path)
          @display.show_error("Workflow not found: #{workflow_path}")
          return
        end
        
        # Capture output to add to conversation
        workflow_output = []
        original_stdout = $stdout
        
        ::CLI::UI::Frame.open("Running Workflow: #{workflow_name}", color: :cyan, timing: true) do
          begin
            # Create a custom IO that captures and displays output
            output_capture = StringIO.new
            multi_io = MultiIO.new(original_stdout, output_capture)
            
            # Temporarily redirect stdout to capture workflow output
            $stdout = multi_io
            
            # Execute workflow
            runner = Roast::Workflow::WorkflowRunner.new(workflow_path, [], verbose: true)
            runner.begin!
            
            # Get the captured output
            workflow_output = output_capture.string
            
            @display.show_success("Workflow completed successfully!")
            
            # Add workflow execution to conversation
            if workflow_output && !workflow_output.empty?
              # Add a user message about running the workflow
              @application.session_manager.add_user_message(
                "I ran the workflow '#{workflow_name}' which executed successfully."
              )
              
              # Add the workflow output as an assistant message
              output_summary = "Here's the output from the workflow execution:\n\n#{workflow_output}"
              @application.session_manager.add_assistant_message(output_summary)
            end
            
          rescue => e
            @display.show_error("Workflow failed: #{e.message}")
            
            # Still capture any partial output
            workflow_output = output_capture.string if defined?(output_capture)
            
            # Add failure info to conversation
            @application.session_manager.add_user_message(
              "I tried to run the workflow '#{workflow_name}' but it failed with: #{e.message}"
            )
            
            if workflow_output && !workflow_output.empty?
              @application.session_manager.add_assistant_message(
                "Partial output before failure:\n\n#{workflow_output}"
              )
            end
            
            if ENV["DEBUG"]
              @display.show_debug("Error class: #{e.class}")
              @display.show_debug("Backtrace:")
              e.backtrace.first(5).each { |line| @display.show_debug("  #{line}") }
            end
          ensure
            # Always restore stdout
            $stdout = original_stdout
          end
        end
      end
      
      # Helper class to write to multiple IO streams
      class MultiIO
        def initialize(*targets)
          @targets = targets
        end
        
        def write(*args)
          @targets.each { |t| t.write(*args) }
        end
        
        def method_missing(method, *args, &block)
          @targets.first.send(method, *args, &block)
        end
        
        def respond_to_missing?(method, include_private = false)
          @targets.first.respond_to?(method, include_private)
        end
      end
      
      def handle_workflow_list(_args)
        roast_dir = File.join(Dir.pwd, "roast")
        
        unless File.directory?(roast_dir)
          @display.show_info("No roast/ directory found. Create workflows with: /workflow create")
          return
        end
        
        workflow_files = Dir.glob(File.join(roast_dir, "**/workflow.yml")).sort
        
        if workflow_files.empty?
          @display.show_info("No workflows found. Create one with: /workflow create")
          return
        end
        
        workflows = workflow_files.map do |file|
          name = File.dirname(file.sub("#{roast_dir}/", ""))
          
          # Try to read description from workflow
          description = nil
          begin
            config = YAML.load_file(file)
            description = config["description"] || config["name"]
          rescue
            # Ignore errors reading workflow
          end
          
          {
            name: name,
            path: file,
            description: description
          }
        end
        
        @display.show_workflow_list(workflows)
      end
      
      def handle_agent(args)
        subcommand = args.shift
        
        case subcommand
        when "switch"
          agent_name = args.join(" ")
          if agent_name.empty?
            @display.show_error("Agent name is required")
            @display.show_info("Usage: /agent switch <agent_name>")
          else
            @application.switch_agent(agent_name)
          end
        else
          @display.show_error("Unknown agent command: #{subcommand}")
          @display.show_info("Usage: /agent switch <agent_name>")
        end
      end
      
      def handle_status(_args)
        summary = @application.session_manager.conversation_summary
        
        ::CLI::UI::Frame.open("Session Status", color: :cyan) do
          puts ::CLI::UI.fmt("{{bold:Messages:}} #{summary[:message_count]}")
          puts ::CLI::UI.fmt("{{bold:User:}} #{summary[:user_messages]} | {{bold:Assistant:}} #{summary[:assistant_messages]}")
          puts ::CLI::UI.fmt("{{bold:Tool Calls:}} #{summary[:tool_calls]}")
          puts ::CLI::UI.fmt("{{bold:Tokens:}} ~#{summary[:total_tokens]}")
          
          duration = summary[:duration]
          if duration > 0
            minutes = duration / 60
            seconds = duration % 60
            puts ::CLI::UI.fmt("{{bold:Duration:}} #{minutes}m #{seconds}s")
          end
          
          if summary[:metadata].any?
            puts ::CLI::UI.fmt("{{bold:Metadata:}}")
            summary[:metadata].each do |key, value|
              puts ::CLI::UI.fmt("  {{info:#{key}}}: #{value}")
            end
          end
        end
      end
      
      def handle_save(args)
        filename = args.first || generate_default_filename
        path = File.expand_path(filename)
        
        @application.session_manager.save_to_file(path)
        @display.show_success("Session saved to: #{path}")
      end
      
      def handle_load(args)
        filename = args.first
        
        if filename.nil? || filename.empty?
          @display.show_error("Filename is required")
          @display.show_info("Usage: /load <filename>")
          return
        end
        
        path = File.expand_path(filename)
        
        unless File.exist?(path)
          @display.show_error("File not found: #{path}")
          return
        end
        
        @application.session_manager.load_from_file(path)
        @display.show_success("Session loaded from: #{path}")
        
        # Show summary
        summary = @application.session_manager.conversation_summary
        @display.show_info("Loaded #{summary[:message_count]} messages")
      end
      
      def handle_history(args)
        count = args.first&.to_i || 10
        messages = @application.session_manager.get_messages(limit: count)
        
        ::CLI::UI::Frame.open("Conversation History", color: :cyan) do
          if messages.empty?
            puts "No messages yet"
          else
            messages.each do |msg|
              role_color = Display::COLORS[msg[:role].to_sym] || :default
              timestamp = msg[:timestamp]&.strftime("%H:%M:%S") || ""
              
              puts ::CLI::UI.fmt("{{#{role_color}:[#{timestamp}] #{msg[:role].capitalize}:}}")
              
              # Truncate long messages in history view
              content = msg[:content] || ""
              if content.length > 200
                puts "#{content[0..200]}..."
              else
                puts content
              end
              puts
            end
          end
        end
      end
      
      def prompt_for_input(prompt)
        ::CLI::UI::Prompt.ask(prompt)
      rescue Interrupt
        nil
      end
      
      def generate_default_filename
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        "roast_session_#{timestamp}.json"
      end
    end
  end
end