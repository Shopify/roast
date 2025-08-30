# typed: true
# frozen_string_literal: true

module Roast
  module Commands
    class Init < Command
      def invoke(args, name)
        options = parse_options(args, name)

        if options[:example]
          copy_example(options[:example])
        else
          show_example_picker
        end
      end

      def help_message
        <<~HELP
          Initialize a new Roast workflow from an example

          Usage: roast init

          Options:
            -e, --example NAME         Name of the example to use directly (skips picker)
        HELP
      end

      def configure_options(command_name, parser, options)
        parser.on("-e", "--example NAME") { |name| options[:example] = name }
      end

      private

      def show_example_picker
        examples = available_examples

        if examples.empty?
          puts "No examples found!"
          return
        end

        puts "Select an option:"
        choices = ["Pick from examples", "New from prompt (beta)"]

        selected = run_picker(choices, "Select initialization method:")

        case selected
        when "Pick from examples"
          example_choice = run_picker(examples, "Select an example:")
          copy_example(example_choice) if example_choice
        when "New from prompt (beta)"
          create_from_prompt
        end
      end

      def available_examples
        examples_dir = File.join(Roast::ROOT, "examples")
        return [] unless File.directory?(examples_dir)

        Dir.entries(examples_dir)
          .select { |entry| File.directory?(File.join(examples_dir, entry)) && entry != "." && entry != ".." }
          .sort
      end

      def run_picker(options, prompt)
        return if options.empty?

        CLI::UI::Prompt.ask(prompt) do |handler|
          options.each { |option| handler.option(option) { |selection| selection } }
        end
      end

      def copy_example(example_name)
        examples_dir = File.join(Roast::ROOT, "examples")
        source_path = File.join(examples_dir, example_name)
        target_path = File.join(Dir.pwd, example_name)

        unless File.directory?(source_path)
          puts "Example '#{example_name}' not found!"
          return
        end

        if File.exist?(target_path)
          puts "Directory '#{example_name}' already exists in current directory!"
          return
        end

        FileUtils.cp_r(source_path, target_path)
        puts "Successfully copied example '#{example_name}' to current directory."
      end

      def create_from_prompt
        puts("Create a new workflow from a description")
        puts

        # Execute the workflow generator
        generator_path = File.join(Roast::ROOT, "examples", "workflow_generator", "workflow.yml")

        begin
          # Execute the workflow generator (it will handle user input)
          Roast::Workflow::WorkflowRunner.new(generator_path, [], {}).begin!

          puts
          puts("Workflow generation complete!")
        rescue => e
          puts("Error generating workflow: #{e.message}")
        end
      end
    end
  end
end
