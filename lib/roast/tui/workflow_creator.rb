# typed: true
# frozen_string_literal: true

require "yaml"

module Roast
  module TUI
    class WorkflowCreator
      WORKFLOW_CREATION_PROMPT = <<~PROMPT
        You are an expert at creating Roast workflows. Generate a valid Roast workflow YAML configuration based on the user's description.

        Important rules:
        1. The 'steps' array contains step names, inline prompts, or control flow keywords
        2. Step configuration goes in top-level hash with step name as key, NOT inline in steps
        3. Use inline prompt syntax for simple prompts (just a string in the steps array)
        4. Tools are capabilities available to the LLM, not explicitly invoked
        5. Include appropriate tools based on the task requirements
        6. Use descriptive step names for complex steps
        7. Follow the exact YAML structure required by Roast

        Generate a complete, valid workflow YAML that accomplishes the user's goal.
        Return ONLY the YAML content, no explanations or markdown code blocks.
      PROMPT

      attr_reader :llm_client, :session_manager

      def initialize(llm_client: nil, session_manager: nil)
        @llm_client = llm_client || LLMClient.new
        @session_manager = session_manager || SessionManager.new
      end

      # Generate a workflow from natural language description
      def create_from_description(description, options = {})
        ::CLI::UI::Frame.open("Creating Workflow", timing: true) do
          puts ::CLI::UI.fmt("{{cyan:Analyzing requirements...}}")

          workflow_yaml = generate_workflow_yaml(description)

          if workflow_yaml
            display_workflow(workflow_yaml)

            if options[:interactive]
              workflow_yaml = refine_workflow_interactive(workflow_yaml, description)
            end

            if validate_workflow(workflow_yaml)
              save_path = save_workflow(workflow_yaml, options[:name])
              puts ::CLI::UI.fmt("{{green:✓}} Workflow saved to: {{bold:#{save_path}}}")
              save_path
            else
              puts ::CLI::UI.fmt("{{red:✗}} Generated workflow has validation errors")
              nil
            end
          else
            puts ::CLI::UI.fmt("{{red:✗}} Failed to generate workflow")
            nil
          end
        end
      end

      # Interactive refinement with user feedback
      def refine_workflow_interactive(workflow_yaml, original_description)
        loop do
          puts ::CLI::UI.fmt("\n{{bold:Options:}}")
          choice = ::CLI::UI::Prompt.ask("What would you like to do?") do |handler|
            handler.option("Accept workflow")    { :accept }
            handler.option("Refine workflow")    { :refine }
            handler.option("Add tools")          { :add_tools }
            handler.option("Modify steps")       { :modify_steps }
            handler.option("Start over")         { :restart }
            handler.option("Cancel")             { :cancel }
          end

          case choice
          when :accept
            return workflow_yaml
          when :refine
            refinement = ::CLI::UI.ask("Describe the changes you want:")
            workflow_yaml = refine_workflow(workflow_yaml, refinement)
            display_workflow(workflow_yaml)
          when :add_tools
            workflow_yaml = add_tools_interactive(workflow_yaml)
            display_workflow(workflow_yaml)
          when :modify_steps
            workflow_yaml = modify_steps_interactive(workflow_yaml)
            display_workflow(workflow_yaml)
          when :restart
            return create_from_description(original_description, interactive: false)
          when :cancel
            return
          end
        end
      end

      # Generate workflow suggestions based on directory context
      def suggest_workflows(directory = ".")
        ::CLI::UI::Frame.open("Workflow Suggestions") do
          file_types = analyze_directory(directory)

          suggestions = generate_suggestions(file_types)

          if suggestions.any?
            puts ::CLI::UI.fmt("{{bold:Based on your project structure, here are some workflow suggestions:}}\n")

            suggestions.each_with_index do |suggestion, index|
              puts ::CLI::UI.fmt("{{cyan:#{index + 1}.}} {{bold:#{suggestion[:name]}}}")
              puts ::CLI::UI.fmt("   #{suggestion[:description]}")
              puts ::CLI::UI.fmt("   {{gray:Tools: #{suggestion[:tools].join(", ")}}}\n")
            end

            suggestions
          else
            puts ::CLI::UI.fmt("{{yellow:No specific suggestions available for this directory}}")
            []
          end
        end
      end

      private

      def generate_workflow_yaml(description)
        messages = [
          {
            role: "system",
            content: WORKFLOW_CREATION_PROMPT,
          },
          {
            role: "user",
            content: "Create a Roast workflow for: #{description}",
          },
        ]

        response = @llm_client.chat_completion(messages, temperature: 0.7)

        # Extract YAML from response
        yaml_content = response.content.strip

        # Remove markdown code blocks if present
        yaml_content = yaml_content.gsub(/^```ya?ml\n/, "").gsub(/\n```$/, "")

        # Validate it's parseable YAML
        begin
          YAML.safe_load(yaml_content)
          yaml_content
        rescue => e
          puts ::CLI::UI.fmt("{{red:Error parsing generated YAML: #{e.message}}}")
          nil
        end
      end

      def refine_workflow(workflow_yaml, refinement_request)
        messages = [
          {
            role: "system",
            content: WORKFLOW_CREATION_PROMPT,
          },
          {
            role: "user",
            content: "Here is the current workflow:\n\n#{workflow_yaml}\n\nPlease modify it based on this request: #{refinement_request}\n\nReturn ONLY the updated YAML.",
          },
        ]

        response = @llm_client.chat_completion(messages, temperature: 0.7)

        yaml_content = response.content.strip.gsub(/^```ya?ml\n/, "").gsub(/\n```$/, "")

        begin
          YAML.safe_load(yaml_content)
          yaml_content
        rescue
          workflow_yaml # Return original if refinement fails
        end
      end

      def add_tools_interactive(workflow_yaml)
        available_tools = [
          "Roast::Tools::ReadFile",
          "Roast::Tools::WriteFile",
          "Roast::Tools::Grep",
          "Roast::Tools::Search",
          "Roast::Tools::Cmd",
          "Roast::Tools::Input",
          "Roast::Tools::CodingAgent",
        ]

        puts ::CLI::UI.fmt("\n{{bold:Available tools:}}")
        available_tools.each_with_index do |tool, index|
          puts ::CLI::UI.fmt("  {{cyan:#{index + 1}.}} #{tool}")
        end

        selection = ::CLI::UI.ask("Enter tool numbers to add (comma-separated):")

        if selection && !selection.strip.empty?
          indices = selection.split(",").map { |s| s.strip.to_i - 1 }
          selected_tools = indices.map { |i| available_tools[i] }.compact

          if selected_tools.any?
            workflow = YAML.safe_load(workflow_yaml)
            workflow["tools"] ||= []
            workflow["tools"] = (workflow["tools"] + selected_tools).uniq
            YAML.dump(workflow)
          else
            workflow_yaml
          end
        else
          workflow_yaml
        end
      end

      def modify_steps_interactive(workflow_yaml)
        workflow = YAML.safe_load(workflow_yaml)

        puts ::CLI::UI.fmt("\n{{bold:Current steps:}}")
        workflow["steps"].each_with_index do |step, index|
          puts ::CLI::UI.fmt("  {{cyan:#{index + 1}.}} #{step}")
        end

        action = ::CLI::UI::Prompt.ask("What would you like to do?") do |handler|
          handler.option("Add step")     { :add }
          handler.option("Remove step")  { :remove }
          handler.option("Reorder steps") { :reorder }
          handler.option("Edit step")    { :edit }
          handler.option("Cancel")       { :cancel }
        end

        case action
        when :add
          position = ::CLI::UI.ask("Insert at position (1-#{workflow["steps"].size + 1}):", Integer)
          step_content = ::CLI::UI.ask("Enter step content (name or inline prompt):")

          if position && step_content
            workflow["steps"].insert(position - 1, step_content)
          end
        when :remove
          position = ::CLI::UI.ask("Remove step number:", Integer)

          if position && position > 0 && position <= workflow["steps"].size
            workflow["steps"].delete_at(position - 1)
          end
        when :reorder
          from = ::CLI::UI.ask("Move step from position:", Integer)
          to = ::CLI::UI.ask("Move to position:", Integer)

          if from && to && from > 0 && to > 0
            step = workflow["steps"].delete_at(from - 1)
            workflow["steps"].insert(to - 1, step) if step
          end
        when :edit
          position = ::CLI::UI.ask("Edit step number:", Integer)

          if position && position > 0 && position <= workflow["steps"].size
            new_content = ::CLI::UI.ask("Enter new step content:", default: workflow["steps"][position - 1])
            workflow["steps"][position - 1] = new_content if new_content
          end
        end

        YAML.dump(workflow) unless action == :cancel
      end

      def display_workflow(workflow_yaml)
        ::CLI::UI::Frame.open("Generated Workflow") do
          puts workflow_yaml
        end
      end

      def validate_workflow(workflow_yaml)
        config = YAML.safe_load(workflow_yaml)

        # Basic validation
        errors = []
        errors << "Missing 'name' field" unless config["name"]
        errors << "Missing 'steps' field" unless config["steps"]
        errors << "Steps must be an array" unless config["steps"].is_a?(Array)
        errors << "Steps cannot be empty" if config["steps"]&.empty?

        if errors.any?
          puts ::CLI::UI.fmt("{{red:Validation errors:}}")
          errors.each { |error| puts ::CLI::UI.fmt("  {{red:• #{error}}}") }
          false
        else
          puts ::CLI::UI.fmt("{{green:✓}} Workflow validation passed")
          true
        end
      rescue => e
        puts ::CLI::UI.fmt("{{red:Invalid YAML: #{e.message}}}")
        false
      end

      def save_workflow(workflow_yaml, custom_name = nil)
        config = YAML.safe_load(workflow_yaml)

        # Generate filename
        base_name = custom_name || config["name"]&.downcase&.gsub(/\s+/, "_") || "workflow"
        filename = "#{base_name}.yml"

        # Find unique filename if exists
        counter = 1
        while File.exist?(filename)
          filename = "#{base_name}_#{counter}.yml"
          counter += 1
        end

        # Save to file
        File.write(filename, workflow_yaml)
        filename
      end

      def analyze_directory(directory)
        file_types = {
          ruby: Dir.glob("#{directory}/**/*.rb").any?,
          javascript: Dir.glob("#{directory}/**/*.{js,jsx,ts,tsx}").any?,
          python: Dir.glob("#{directory}/**/*.py").any?,
          markdown: Dir.glob("#{directory}/**/*.md").any?,
          yaml: Dir.glob("#{directory}/**/*.{yml,yaml}").any?,
          json: Dir.glob("#{directory}/**/*.json").any?,
          csv: Dir.glob("#{directory}/**/*.csv").any?,
        }

        file_types.select { |_, exists| exists }.keys
      end

      def generate_suggestions(file_types)
        suggestions = []

        if file_types.include?(:ruby)
          suggestions << {
            name: "Ruby Code Analysis",
            description: "Analyze Ruby code for quality, security, and performance issues",
            tools: ["Roast::Tools::ReadFile", "Roast::Tools::Grep", "Roast::Tools::CodingAgent"],
          }
        end

        if file_types.include?(:csv)
          suggestions << {
            name: "CSV Data Analysis",
            description: "Analyze CSV files for patterns, insights, and data quality",
            tools: ["Roast::Tools::ReadFile", "Roast::Tools::Search"],
          }
        end

        if file_types.include?(:markdown)
          suggestions << {
            name: "Documentation Review",
            description: "Review and improve markdown documentation",
            tools: ["Roast::Tools::ReadFile", "Roast::Tools::WriteFile"],
          }
        end

        if file_types.include?(:yaml) || file_types.include?(:json)
          suggestions << {
            name: "Configuration Validation",
            description: "Validate and analyze configuration files",
            tools: ["Roast::Tools::ReadFile", "Roast::Tools::Search"],
          }
        end

        suggestions
      end
    end
  end
end
